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

/// StateNotifier for managing client records
class ClientRecordsNotifier extends StateNotifier<List<ClientMeterRecord>> {
  final MeterRepository _repository;

  ClientRecordsNotifier(this._repository) : super([]);

  /// Load all clients from the database
  Future<void> loadClients() async {
    await _repository.seedIfEmpty();
    state = await _repository.getAllClients();
  }

  /// Save a reading for a specific client
  Future<void> saveReading(String clientId, int currentReading) async {
    final client = await _repository.getClient(clientId);
    if (client == null) return;

    final updated = ClientMeterRecord(
      id: client.id,
      clientNumber: client.clientNumber,
      ownerName: client.ownerName,
      readingTwoMonthsAgo: client.readingTwoMonthsAgo,
      readingOneMonthAgo: client.readingOneMonthAgo,
      currentReading: currentReading,
      isVisited: true,
      latitude: client.latitude,
      longitude: client.longitude,
      updatedAt: DateTime.now(),
    );

    await _repository.saveClient(updated);
    state = await _repository.getAllClients();
  }

  /// Create a new client from a map pin drop
  Future<ClientMeterRecord> addClient({
    required String ownerName,
    required String clientNumber,
    required double latitude,
    required double longitude,
    int readingTwoMonthsAgo = 0,
    int readingOneMonthAgo = 0,
    int? currentReading,
  }) async {
    final record = await _repository.createClient(
      ownerName: ownerName,
      clientNumber: clientNumber,
      latitude: latitude,
      longitude: longitude,
      readingTwoMonthsAgo: readingTwoMonthsAgo,
      readingOneMonthAgo: readingOneMonthAgo,
      currentReading: currentReading,
    );
    state = await _repository.getAllClients();
    return record;
  }

  /// Delete a client
  Future<void> deleteClient(String clientId) async {
    await _repository.deleteClient(clientId);
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

/// Derived provider: progress stats
final routeProgressProvider = Provider<({int total, int visited, double percent})>((ref) {
  final records = ref.watch(clientRecordsProvider);
  final total = records.length;
  final visited = records.where((r) => r.isVisited).length;
  final percent = total > 0 ? (visited / total) * 100 : 0.0;
  return (total: total, visited: visited, percent: percent);
});
