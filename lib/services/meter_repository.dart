import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../data/initial_clients.dart';
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

  /// Map center of the route (Sol de las Praderas); seeded pins are laid
  /// out around it.
  static const _seedCenterLat = -30.729639;
  static const _seedCenterLng = -70.764389;

  /// ~130 m between seeded pins, so they don't overlap at street zoom.
  static const _seedSpacing = 0.0012;
  static const _seedColumns = 10;

  /// Note stored on every seeded client until the reader fixes its pin.
  static const seedLocationNote =
      'Ubicación por confirmar: use "Reubicar" en la primera visita.';

  /// Loads the official client list ([initialClients]) when the database
  /// is empty (first launch). Returns how many clients were added.
  ///
  /// The list has no coordinates or previous readings: readings start at 0
  /// and pins are placed on a grid per sector around the map center (each
  /// sector in its own block), flagged with [seedLocationNote] so the
  /// reader relocates them in the field.
  Future<int> seedIfEmpty() async {
    final box = await _getBox();
    if (box.isNotEmpty) return 0;

    // Group by sector, keeping the list order
    final bySector = <String, List<(String, String, String)>>{};
    for (final client in initialClients) {
      bySector.putIfAbsent(client.$3, () => []).add(client);
    }

    // Total grid rows (plus one blank row between sectors), to center it
    final totalRows = bySector.values
            .map((c) => (c.length / _seedColumns).ceil())
            .fold(0, (a, b) => a + b) +
        bySector.length -
        1;
    final firstRowLat = _seedCenterLat + totalRows / 2 * _seedSpacing;

    final records = <String, ClientMeterRecord>{};
    var row = 0;
    for (final clients in bySector.values) {
      for (var i = 0; i < clients.length; i++) {
        final (number, name, sector) = clients[i];
        final col = i % _seedColumns;
        final r = row + i ~/ _seedColumns;
        final record = ClientMeterRecord(
          id: 'seed-$number',
          clientNumber: number,
          ownerName: name,
          readingTwoMonthsAgo: 0,
          readingOneMonthAgo: 0,
          latitude: firstRowLat - r * _seedSpacing,
          longitude: _seedCenterLng +
              (col - (_seedColumns - 1) / 2) * _seedSpacing,
          sector: sector,
          observations: seedLocationNote,
        );
        records[record.id] = record;
      }
      row += (clients.length / _seedColumns).ceil() + 1;
    }

    await box.putAll(records);
    return records.length;
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

  /// Create a new client dynamically from map pin drop. New clients start
  /// pending; their first reading is taken from the reading screen.
  Future<ClientMeterRecord> createClient({
    required String ownerName,
    required String clientNumber,
    required double latitude,
    required double longitude,
    int readingTwoMonthsAgo = 0,
    int readingOneMonthAgo = 0,
  }) async {
    final id = 'dyn-${_uuid.v4().substring(0, 8)}';

    final record = ClientMeterRecord(
      id: id,
      clientNumber: clientNumber,
      ownerName: ownerName,
      readingTwoMonthsAgo: readingTwoMonthsAgo,
      readingOneMonthAgo: readingOneMonthAgo,
      latitude: latitude,
      longitude: longitude,
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

  /// Update an existing client's geographical location
  Future<void> updateClientLocation(String id, double newLat, double newLng) async {
    final box = await _getBox();
    final client = box.get(id);
    if (client != null) {
      final updated = client.copyWith(
        latitude: newLat,
        longitude: newLng,
      );
      await box.put(id, updated);
    }
  }

  /// Close the current cycle and prepare every record for the next one.
  /// See [ClientMeterRecord.startNewCycle] for how history is handled.
  Future<void> resetAllReadings() async {
    final box = await _getBox();
    await box.putAll({
      for (final client in box.values) client.id: client.startNewCycle(),
    });
  }

  /// Replace every stored client with [records] (monthly route import).
  /// New records are written before old ones are deleted, so a failure
  /// part-way never leaves the route empty.
  Future<void> replaceAllClients(List<ClientMeterRecord> records) async {
    final box = await _getBox();
    final newIds = {for (final r in records) r.id};
    final staleIds = box.keys.where((key) => !newIds.contains(key)).toList();
    await box.putAll({for (final r in records) r.id: r});
    await box.deleteAll(staleIds);
  }
}
