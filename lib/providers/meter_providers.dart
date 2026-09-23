import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/client_meter_record.dart';
import '../services/meter_repository.dart';
import '../services/excel_export_service.dart';
import '../services/excel_import_service.dart';
import '../services/location_service.dart';
import '../services/photo_service.dart';

/// Repository singleton provider
final meterRepositoryProvider = Provider<MeterRepository>((ref) {
  return MeterRepository();
});

/// Excel export service provider
final excelExportServiceProvider = Provider<ExcelExportService>((ref) {
  return ExcelExportService();
});

/// Thrown when creating a client whose number is already in use.
class DuplicateClientNumberException implements Exception {
  final String clientNumber;
  DuplicateClientNumberException(this.clientNumber);

  @override
  String toString() => 'Ya existe un cliente con el N° $clientNumber';
}

/// Excel import service provider (overridable in tests)
final excelImportServiceProvider = Provider<ExcelImportService>((ref) {
  return ExcelImportService();
});

/// Device location for the GPS audit of visits (overridable in tests)
final locationServiceProvider = Provider<LocationService>((ref) {
  return const LocationService();
});

/// Camera evidence photos (overridable in tests)
final photoServiceProvider = Provider<PhotoService>((ref) {
  return PhotoService();
});

/// StateNotifier for managing client records
class ClientRecordsNotifier extends StateNotifier<List<ClientMeterRecord>> {
  final MeterRepository _repository;
  final LocationService _locationService;

  ClientRecordsNotifier(
    this._repository, [
    this._locationService = const LocationService(),
  ]) : super([]);

  /// Load all clients from the database. On first launch (empty
  /// database) the official client list is loaded first.
  Future<void> loadClients() async {
    await _repository.seedIfEmpty();
    state = await _repository.getAllClients();
  }

  /// Record the result of a visit: either a [reading] or a
  /// [nonReadingReason] (exactly one of them), plus optional [observations].
  /// Saving one clears the other, so a record never holds both.
  ///
  /// Also stores where the device was (GPS audit). Without location the
  /// visit is still saved, with null coordinates: the reader's work is
  /// never blocked by GPS. [photoPath] is the optional evidence photo.
  /// Returns the saved record.
  Future<ClientMeterRecord?> saveReading(
    String clientId, {
    int? reading,
    String? nonReadingReason,
    String? observations,
    String? photoPath,
  }) async {
    if ((reading == null) == (nonReadingReason == null)) {
      throw ArgumentError(
          'Provide either a reading or a non-reading reason, not both.');
    }

    final client = await _repository.getClient(clientId);
    if (client == null) return null;

    final position = await _locationService.currentPosition();
    final trimmedObservations = observations?.trim();
    final updated = ClientMeterRecord(
      id: client.id,
      clientNumber: client.clientNumber,
      ownerName: client.ownerName,
      readingTwoMonthsAgo: client.readingTwoMonthsAgo,
      readingOneMonthAgo: client.readingOneMonthAgo,
      currentReading: reading,
      isVisited: true,
      latitude: client.latitude,
      longitude: client.longitude,
      updatedAt: DateTime.now(),
      nonReadingReason: nonReadingReason,
      observations: (trimmedObservations == null || trimmedObservations.isEmpty)
          ? null
          : trimmedObservations,
      readingLatitude: position?.latitude,
      readingLongitude: position?.longitude,
      photoPath: photoPath,
      sector: client.sector,
    );

    await _repository.saveClient(updated);
    state = await _repository.getAllClients();
    return updated;
  }

  /// Whether [clientNumber] is already used by a client other than
  /// [exceptClientId] (pass the edited client's id when editing).
  bool isClientNumberTaken(String clientNumber, {String? exceptClientId}) {
    final normalized = clientNumber.trim();
    return state.any((c) =>
        c.id != exceptClientId && c.clientNumber.trim() == normalized);
  }

  /// Create a new client from a map pin drop
  Future<ClientMeterRecord> addClient({
    required String ownerName,
    required String clientNumber,
    required double latitude,
    required double longitude,
    int readingTwoMonthsAgo = 0,
    int readingOneMonthAgo = 0,
  }) async {
    if (isClientNumberTaken(clientNumber)) {
      throw DuplicateClientNumberException(clientNumber.trim());
    }
    final record = await _repository.createClient(
      ownerName: ownerName,
      clientNumber: clientNumber,
      latitude: latitude,
      longitude: longitude,
      readingTwoMonthsAgo: readingTwoMonthsAgo,
      readingOneMonthAgo: readingOneMonthAgo,
    );
    state = await _repository.getAllClients();
    return record;
  }

  /// Delete a client
  Future<void> deleteClient(String clientId) async {
    await _repository.deleteClient(clientId);
    state = await _repository.getAllClients();
  }

  /// Update client location (relocate pin)
  Future<void> updateClientLocation(String clientId, double newLat, double newLng) async {
    await _repository.updateClientLocation(clientId, newLat, newLng);
    state = await _repository.getAllClients();
  }

  /// Edits a client's master data (name, sector and reading history).
  /// The current cycle (reading, visit state, reason, observations, photo)
  /// and the location are not touched. An empty [sector] clears it.
  Future<void> updateClientData(
    String clientId, {
    required String ownerName,
    required String? sector,
    required int readingOneMonthAgo,
    required int readingTwoMonthsAgo,
  }) async {
    if (readingOneMonthAgo < readingTwoMonthsAgo) {
      throw ArgumentError(
          'La lectura de hace 1 mes no puede ser menor que la de hace 2 meses.');
    }
    final client = await _repository.getClient(clientId);
    if (client == null) return;
    final trimmedSector = sector?.trim();
    await _repository.saveClient(client.withMasterData(
      ownerName: ownerName.trim(),
      sector:
          (trimmedSector == null || trimmedSector.isEmpty) ? null : trimmedSector,
      readingOneMonthAgo: readingOneMonthAgo,
      readingTwoMonthsAgo: readingTwoMonthsAgo,
      latitude: client.latitude,
      longitude: client.longitude,
    ));
    state = await _repository.getAllClients();
  }

  /// Removes the client's map location (its pin disappears until it is
  /// placed again). Nothing else changes.
  Future<void> clearClientLocation(String clientId) async {
    final client = await _repository.getClient(clientId);
    if (client == null) return;
    await _repository.saveClient(client.withMasterData(
      ownerName: client.ownerName,
      sector: client.sector,
      readingOneMonthAgo: client.readingOneMonthAgo,
      readingTwoMonthsAgo: client.readingTwoMonthsAgo,
      latitude: null,
      longitude: null,
    ));
    state = await _repository.getAllClients();
  }

  /// Applies a base template (route file without "Lectura Actual") on top
  /// of the current route, matching clients by N° de cliente:
  /// - existing clients get the file's name, sector, reading history and,
  ///   when the file has them, coordinates (empty coordinates never erase
  ///   a location already placed); their current cycle is kept intact.
  /// - clients not in the route are added as pending.
  /// - clients missing from the file are kept (no reading is ever lost).
  Future<({int updated, int added})> mergeClients(
      List<ClientMeterRecord> records) async {
    final byNumber = {for (final c in state) c.clientNumber.trim(): c};
    final toSave = <ClientMeterRecord>[];
    var updated = 0, added = 0;
    for (final record in records) {
      final existing = byNumber[record.clientNumber.trim()];
      if (existing == null) {
        toSave.add(record);
        added++;
        continue;
      }
      toSave.add(existing.withMasterData(
        ownerName: record.ownerName,
        sector: record.sector ?? existing.sector,
        readingOneMonthAgo: record.readingOneMonthAgo,
        readingTwoMonthsAgo: record.readingTwoMonthsAgo,
        latitude: record.hasLocation ? record.latitude : existing.latitude,
        longitude: record.hasLocation ? record.longitude : existing.longitude,
      ));
      updated++;
    }
    await _repository.saveClients(toSave);
    state = await _repository.getAllClients();
    return (updated: updated, added: added);
  }

  /// Reset all readings for a new cycle
  Future<void> resetAll() async {
    await _repository.resetAllReadings();
    state = await _repository.getAllClients();
  }

  /// Replace the whole route with imported [records]; returns how many
  /// clients were imported.
  Future<int> importClients(List<ClientMeterRecord> records) async {
    await _repository.replaceAllClients(records);
    state = await _repository.getAllClients();
    return records.length;
  }
}

/// Provider for the client records state notifier
final clientRecordsProvider =
    StateNotifierProvider<ClientRecordsNotifier, List<ClientMeterRecord>>((ref) {
  final repository = ref.watch(meterRepositoryProvider);
  return ClientRecordsNotifier(repository, ref.watch(locationServiceProvider));
});

/// Route progress for the current cycle. [visited] = [read] + [noReading].
typedef RouteProgress = ({
  int total,
  int visited,
  int read,
  int noReading,
  double percent,
});

/// Derived provider: progress stats
final routeProgressProvider = Provider<RouteProgress>((ref) {
  final records = ref.watch(clientRecordsProvider);
  final total = records.length;
  final read =
      records.where((r) => r.visitStatus == VisitStatus.read).length;
  final noReading =
      records.where((r) => r.visitStatus == VisitStatus.noReading).length;
  final visited = read + noReading;
  final percent = total > 0 ? (visited / total) * 100 : 0.0;
  return (
    total: total,
    visited: visited,
    read: read,
    noReading: noReading,
    percent: percent,
  );
});
