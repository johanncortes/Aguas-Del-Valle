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

  /// Loads the official client list ([initialClients]) when the database
  /// is empty (first launch). Returns how many clients were added.
  ///
  /// The list has no coordinates or previous readings: clients are created
  /// without a location (no map pin) and with readings at 0. The reader
  /// finds them in the client list and fixes each location in the field.
  Future<int> seedIfEmpty() async {
    final box = await _getBox();
    if (box.isNotEmpty) {
      await _clearLegacySeedGrid(box);
      return 0;
    }

    final records = {
      for (final (number, name, sector) in initialClients)
        'seed-$number': ClientMeterRecord(
          id: 'seed-$number',
          clientNumber: number,
          ownerName: name,
          readingTwoMonthsAgo: 0,
          readingOneMonthAgo: 0,
          sector: sector,
        ),
    };
    await box.putAll(records);
    return records.length;
  }

  /// Note that marked the placeholder grid positions of a previous version.
  static const _legacySeedLocationNote =
      'Ubicación por confirmar: use "Reubicar" en la primera visita.';

  /// A previous version placed preloaded clients on an invented grid.
  /// Removes those placeholder positions (and their note) from clients that
  /// still carry the note and were not visited, so they leave the map.
  Future<void> _clearLegacySeedGrid(Box<ClientMeterRecord> box) async {
    final updates = <String, ClientMeterRecord>{};
    for (final c in box.values) {
      if (c.id.startsWith('seed-') &&
          c.observations == _legacySeedLocationNote &&
          !c.isVisited) {
        updates[c.id] = ClientMeterRecord(
          id: c.id,
          clientNumber: c.clientNumber,
          ownerName: c.ownerName,
          readingTwoMonthsAgo: c.readingTwoMonthsAgo,
          readingOneMonthAgo: c.readingOneMonthAgo,
          sector: c.sector,
        );
      }
    }
    if (updates.isNotEmpty) await box.putAll(updates);
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
