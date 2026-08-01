import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/client_meter_record.dart';

class MeterRepository {
  static const String _boxName = 'meter_records';
  static const _uuid = Uuid();

  Future<Box<ClientMeterRecord>> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox<ClientMeterRecord>(_boxName);
    }
    return Hive.box<ClientMeterRecord>(_boxName);
  }

  /// Initialize database with mock data along the rural path
  /// from Monte Patria towards Sol de las Praderas
  /// centered around -30.729639, -70.764389
  Future<void> seedIfEmpty() async {
    final box = await _getBox();
    if (box.isNotEmpty) return;

    final mockClients = [
      ClientMeterRecord(
        id: 'sp-001',
        clientNumber: '40225001',
        ownerName: 'María Elena Cortés Rojas',
        readingTwoMonthsAgo: 1245,
        readingOneMonthAgo: 1268,
        latitude: -30.7280,
        longitude: -70.7660,
      ),
      ClientMeterRecord(
        id: 'sp-002',
        clientNumber: '40225002',
        ownerName: 'José Luis Araya Muñoz',
        readingTwoMonthsAgo: 890,
        readingOneMonthAgo: 912,
        latitude: -30.7300,
        longitude: -70.7640,
      ),
      ClientMeterRecord(
        id: 'sp-003',
        clientNumber: '40225003',
        ownerName: 'Catalina Fernández López',
        readingTwoMonthsAgo: 3401,
        readingOneMonthAgo: 3440,
        latitude: -30.7275,
        longitude: -70.7620,
      ),
      ClientMeterRecord(
        id: 'sp-004',
        clientNumber: '40225004',
        ownerName: 'Pedro Alejandro Tapia Reyes',
        readingTwoMonthsAgo: 567,
        readingOneMonthAgo: 582,
        latitude: -30.7315,
        longitude: -70.7680,
      ),
      ClientMeterRecord(
        id: 'sp-005',
        clientNumber: '40225005',
        ownerName: 'Francisca del Carmen Rojas Soto',
        readingTwoMonthsAgo: 2100,
        readingOneMonthAgo: 2134,
        latitude: -30.7290,
        longitude: -70.7600,
      ),
      ClientMeterRecord(
        id: 'sp-006',
        clientNumber: '40225006',
        ownerName: 'Roberto Andrés Vega Castillo',
        readingTwoMonthsAgo: 1890,
        readingOneMonthAgo: 1920,
        latitude: -30.7330,
        longitude: -70.7655,
      ),
      ClientMeterRecord(
        id: 'sp-007',
        clientNumber: '40225007',
        ownerName: 'Isabel Cristina Morales Peña',
        readingTwoMonthsAgo: 445,
        readingOneMonthAgo: 458,
        latitude: -30.7260,
        longitude: -70.7635,
      ),
      ClientMeterRecord(
        id: 'sp-008',
        clientNumber: '40225008',
        ownerName: 'Héctor Manuel González Díaz',
        readingTwoMonthsAgo: 3200,
        readingOneMonthAgo: 3245,
        latitude: -30.7310,
        longitude: -70.7610,
      ),
      ClientMeterRecord(
        id: 'sp-009',
        clientNumber: '40225009',
        ownerName: 'Lorena Patricia Silva Herrera',
        readingTwoMonthsAgo: 780,
        readingOneMonthAgo: 798,
        latitude: -30.7340,
        longitude: -70.7625,
      ),
      ClientMeterRecord(
        id: 'sp-010',
        clientNumber: '40225010',
        ownerName: 'Andrés Felipe Contreras Bravo',
        readingTwoMonthsAgo: 1560,
        readingOneMonthAgo: 1588,
        latitude: -30.7270,
        longitude: -70.7675,
      ),
    ];

    for (final client in mockClients) {
      await box.put(client.id, client);
    }
  }

  /// Get all client records
  Future<List<ClientMeterRecord>> getAllClients() async {
    final box = await _getBox();
    return box.values.toList();
  }

  /// Get a single client by ID
  Future<ClientMeterRecord?> getClient(String id) async {
    final box = await _getBox();
    return box.get(id);
  }

  /// Save/update a client record
  Future<void> saveClient(ClientMeterRecord record) async {
    final box = await _getBox();
    await box.put(record.id, record);
  }

  /// Create a new client dynamically from map pin drop
  Future<ClientMeterRecord> createClient({
    required String ownerName,
    required String clientNumber,
    required double latitude,
    required double longitude,
    int readingTwoMonthsAgo = 0,
    int readingOneMonthAgo = 0,
    int? currentReading,
  }) async {
    final id = 'dyn-${_uuid.v4().substring(0, 8)}';
    final hasReading = currentReading != null;

    final record = ClientMeterRecord(
      id: id,
      clientNumber: clientNumber,
      ownerName: ownerName,
      readingTwoMonthsAgo: readingTwoMonthsAgo,
      readingOneMonthAgo: readingOneMonthAgo,
      currentReading: currentReading,
      isVisited: hasReading,
      latitude: latitude,
      longitude: longitude,
      updatedAt: hasReading ? DateTime.now() : null,
    );

    final box = await _getBox();
    await box.put(record.id, record);
    return record;
  }

  /// Delete a client record
  Future<void> deleteClient(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  /// Reset all records for a new cycle
  Future<void> resetAllReadings() async {
    final box = await _getBox();
    final clients = box.values.toList();
    for (final client in clients) {
      final reset = ClientMeterRecord(
        id: client.id,
        clientNumber: client.clientNumber,
        ownerName: client.ownerName,
        readingTwoMonthsAgo: client.readingOneMonthAgo,
        readingOneMonthAgo: client.currentReading ?? client.readingOneMonthAgo,
        currentReading: null,
        isVisited: false,
        latitude: client.latitude,
        longitude: client.longitude,
        updatedAt: null,
      );
      await box.put(reset.id, reset);
    }
  }

  /// Clear all data and reseed (for development / location change)
  Future<void> resetAndReseed() async {
    final box = await _getBox();
    await box.clear();
    await seedIfEmpty();
  }
}
