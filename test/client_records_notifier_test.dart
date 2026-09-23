import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:aguas_monte_patria/models/client_meter_record.dart';
import 'package:aguas_monte_patria/providers/meter_providers.dart';
import 'package:aguas_monte_patria/services/meter_repository.dart';

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

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hive_notifier_test');
    Hive.init(dir.path);
    Hive.registerAdapter(ClientMeterRecordAdapter(), override: true);
    notifier = ClientRecordsNotifier(MeterRepository());
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
    test('starts empty when nothing was imported (no seed data)', () async {
      await Hive.deleteBoxFromDisk('meter_records');
      final fresh = ClientRecordsNotifier(MeterRepository());
      await fresh.loadClients();
      expect(fresh.state, isEmpty);
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
}
