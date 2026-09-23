import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/client_meter_record.dart';
import '../services/meter_repository.dart';
import '../services/excel_export_service.dart';

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

/// StateNotifier for managing client records
class ClientRecordsNotifier extends StateNotifier<List<ClientMeterRecord>> {
  final MeterRepository _repository;

  ClientRecordsNotifier(this._repository) : super([]);

  /// Load all clients from the database
  Future<void> loadClients() async {
    await _repository.seedIfEmpty();
    state = await _repository.getAllClients();
  }

  /// Record the result of a visit: either a [reading] or a
  /// [nonReadingReason] (exactly one of them), plus optional [observations].
  /// Saving one clears the other, so a record never holds both.
  Future<void> saveReading(
    String clientId, {
    int? reading,
    String? nonReadingReason,
    String? observations,
  }) async {
    if ((reading == null) == (nonReadingReason == null)) {
      throw ArgumentError(
          'Provide either a reading or a non-reading reason, not both.');
    }

    final client = await _repository.getClient(clientId);
    if (client == null) return;

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
    );

    await _repository.saveClient(updated);
    state = await _repository.getAllClients();
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

  /// Reset all readings for a new cycle
  Future<void> resetAll() async {
    await _repository.resetAllReadings();
    state = await _repository.getAllClients();
  }

  /// Clear and reseed (for dev / location change)
  Future<void> resetAndReseed() async {
    await _repository.resetAndReseed();
    state = await _repository.getAllClients();
  }
}

/// Provider for the client records state notifier
final clientRecordsProvider =
    StateNotifierProvider<ClientRecordsNotifier, List<ClientMeterRecord>>((ref) {
  final repository = ref.watch(meterRepositoryProvider);
  return ClientRecordsNotifier(repository);
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
