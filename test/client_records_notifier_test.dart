import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:aguas_monte_patria/models/client_meter_record.dart';
import 'package:aguas_monte_patria/providers/meter_providers.dart';
import 'package:aguas_monte_patria/services/meter_repository.dart';
import 'package:aguas_monte_patria/services/location_service.dart';

class _FakeLocationService extends LocationService {
  _FakeLocationService(this.position);
  DevicePosition? position;

  @override
  Future<DevicePosition?> currentPosition() async => position;
}

ClientMeterRecord _client(String id, String number) => ClientMeterRecord(
      id: id,
      clientNumber: number,
      ownerName: 'Cliente $id',
      readingTwoMonthsAgo: 1245,
      readingOneMonthAgo: 1268,
      latitude: -30.728,
      longitude: -70.766,
    );

void main() {
  late Directory dir;
  late ClientRecordsNotifier notifier;
  late _FakeLocationService location;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hive_notifier_test');
    Hive.init(dir.path);
    Hive.registerAdapter(ClientMeterRecordAdapter(), override: true);
    location = _FakeLocationService((latitude: -30.7296, longitude: -70.7644));
    notifier = ClientRecordsNotifier(MeterRepository(), location);
    await notifier.importClients([
      _client('sp-001', '40225001'),
      _client('sp-002', '40225002'),
      _client('sp-003', '40225003'),
    ]);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  ClientMeterRecord record(String id) =>
      notifier.state.firstWhere((c) => c.id == id);

  test('saving a reason clears the reading', () async {
    await notifier.saveReading('sp-001', reading: 1300);
    await notifier.saveReading('sp-001',
        nonReadingReason: 'Perro', observations: '  Perro suelto  ');

    final r = record('sp-001');
    expect(r.currentReading, isNull);
    expect(r.nonReadingReason, 'Perro');
    expect(r.observations, 'Perro suelto');
    expect(r.isVisited, isTrue);
  });

  test('saving a reading clears the reason and empty observations', () async {
    await notifier.saveReading('sp-001',
        nonReadingReason: 'Casa cerrada', observations: 'Volver');
    await notifier.saveReading('sp-001', reading: 1300, observations: '  ');

    final r = record('sp-001');
    expect(r.currentReading, 1300);
    expect(r.nonReadingReason, isNull);
    expect(r.observations, isNull);
  });

  test('rejects both or neither a reading and a reason', () async {
    expect(() => notifier.saveReading('sp-001'), throwsArgumentError);
    expect(
      () => notifier.saveReading('sp-001',
          reading: 1300, nonReadingReason: 'Perro'),
      throwsArgumentError,
    );
  });

  group('client number uniqueness', () {
    test('detects an existing number, ignoring surrounding spaces', () {
      expect(notifier.isClientNumberTaken('40225001'), isTrue);
      expect(notifier.isClientNumberTaken(' 40225001 '), isTrue);
      expect(notifier.isClientNumberTaken('99999999'), isFalse);
    });

    test('allows the edited client to keep its own number', () {
      expect(
        notifier.isClientNumberTaken('40225001', exceptClientId: 'sp-001'),
        isFalse,
      );
      expect(
        notifier.isClientNumberTaken('40225001', exceptClientId: 'sp-002'),
        isTrue,
      );
    });

    test('addClient rejects a duplicate number', () async {
      await expectLater(
        notifier.addClient(
          ownerName: 'Duplicado',
          clientNumber: '40225001',
          latitude: -30.7,
          longitude: -70.7,
        ),
        throwsA(isA<DuplicateClientNumberException>()),
      );
      expect(notifier.state, hasLength(3));
    });
  });

  group('loading and importing', () {
    test('first launch loads the 185 official clients', () async {
      await Hive.deleteBoxFromDisk('meter_records');
      final fresh = ClientRecordsNotifier(MeterRepository());
      await fresh.loadClients();

      final clients = fresh.state;
      expect(clients, hasLength(185));
      final byNumber = {for (final c in clients) c.clientNumber: c};
      expect(byNumber.keys.toSet(),
          {for (var i = 1; i <= 185; i++) '$i'}); // unique N° 1..185
      expect(byNumber['1']!.ownerName, 'Eduardo Osandon Pasten');
      expect(byNumber['1']!.sector, 'Sol de las Praderas');
      expect(byNumber['76']!.ownerName,
          'Sociedad Carrizal ( Puente Carrizal )');
      expect(byNumber['76']!.sector, 'Angostura');
      expect(byNumber['185']!.sector, 'Punta Blanca');

      final sectorCounts = <String, int>{};
      for (final c in clients) {
        sectorCounts[c.sector!] = (sectorCounts[c.sector!] ?? 0) + 1;
      }
      expect(sectorCounts, {
        'Sol de las Praderas': 75,
        'Angostura': 23,
        'Barrancones': 19,
        'Las Condes': 24,
        'Varillar': 18,
        'Punta Blanca': 26,
      });

      // No invented positions: they have no pin until fixed in the field
      for (final c in clients) {
        expect(c.isVisited, isFalse);
        expect(c.readingOneMonthAgo, 0);
        expect(c.latitude, isNull);
        expect(c.longitude, isNull);
        expect(c.hasLocation, isFalse);
        expect(c.observations, isNull);
      }
    });

    test('removes the placeholder grid of the previous version', () async {
      const legacyNote =
          'Ubicación por confirmar: use "Reubicar" en la primera visita.';
      ClientMeterRecord legacy(String number, {bool visited = false}) =>
          ClientMeterRecord(
            id: 'seed-$number',
            clientNumber: number,
            ownerName: 'Cliente $number',
            readingTwoMonthsAgo: 0,
            readingOneMonthAgo: 0,
            currentReading: visited ? 10 : null,
            isVisited: visited,
            latitude: -30.72,
            longitude: -70.76,
            sector: 'Varillar',
            observations: legacyNote,
          );
      await notifier.importClients([
        legacy('1'),
        legacy('2', visited: true), // already visited: left alone
        _client('imp-1', '99'), // imported with real coordinates
      ]);

      final reloaded = ClientRecordsNotifier(MeterRepository());
      await reloaded.loadClients();
      final byId = {for (final c in reloaded.state) c.id: c};

      expect(byId['seed-1']!.hasLocation, isFalse);
      expect(byId['seed-1']!.observations, isNull);
      expect(byId['seed-1']!.sector, 'Varillar');
      expect(byId['seed-2']!.latitude, -30.72);
      expect(byId['imp-1']!.latitude, -30.728);
    });

    test('does not seed over existing data', () async {
      // setUp already imported 3 clients
      final reloaded = ClientRecordsNotifier(MeterRepository());
      await reloaded.loadClients();
      expect(reloaded.state, hasLength(3));
    });

    test('importClients replaces the whole route', () async {
      await notifier.saveReading('sp-001', reading: 1300);

      final count = await notifier.importClients([
        _client('imp-1', '50000001'),
        _client('imp-2', '50000002'),
      ]);

      expect(count, 2);
      expect(notifier.state.map((c) => c.id), unorderedEquals(['imp-1', 'imp-2']));

      // Persisted: a new notifier reading the box sees only the new route
      final reloaded = ClientRecordsNotifier(MeterRepository());
      await reloaded.loadClients();
      expect(reloaded.state.map((c) => c.clientNumber),
          unorderedEquals(['50000001', '50000002']));
    });
  });

  group('GPS audit', () {
    test('stores where the device was when saving', () async {
      final saved = await notifier.saveReading('sp-001', reading: 1300);

      expect(saved?.readingLatitude, -30.7296);
      expect(saved?.readingLongitude, -70.7644);
      expect(record('sp-001').readingLatitude, -30.7296);
    });

    test('saves anyway without location (never blocks the reader)',
        () async {
      location.position = null;

      final saved = await notifier.saveReading('sp-001',
          nonReadingReason: 'Casa cerrada');

      expect(saved?.isVisited, isTrue);
      expect(record('sp-001').nonReadingReason, 'Casa cerrada');
      expect(record('sp-001').readingLatitude, isNull);
      expect(record('sp-001').readingLongitude, isNull);
    });

    test('a new save without location clears the previous position',
        () async {
      await notifier.saveReading('sp-001', reading: 1300);
      location.position = null;
      await notifier.saveReading('sp-001', reading: 1301);

      expect(record('sp-001').readingLatitude, isNull);
    });
  });

  group('evidence photo', () {
    test('saves the photo path and replaces it on a later save', () async {
      await notifier.saveReading('sp-001',
          reading: 1300, photoPath: '/docs/evidence_photos/a.jpg');
      expect(record('sp-001').photoPath, '/docs/evidence_photos/a.jpg');

      await notifier.saveReading('sp-001', reading: 1300);
      expect(record('sp-001').photoPath, isNull);
    });
  });

  group('fix location from GPS', () {
    test('saves the device position as the official location', () async {
      final position = await notifier.fixLocationFromGps('sp-001');

      expect(position?.latitude, -30.7296);
      expect(record('sp-001').latitude, -30.7296);
      expect(record('sp-001').longitude, -70.7644);
    });

    test('changes nothing when no location is available', () async {
      location.position = null;

      expect(await notifier.fixLocationFromGps('sp-001'), isNull);
      expect(record('sp-001').latitude, -30.728); // unchanged
    });
  });
}
