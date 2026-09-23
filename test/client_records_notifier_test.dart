import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:aguas_monte_patria/models/client_meter_record.dart';
import 'package:aguas_monte_patria/providers/meter_providers.dart';
import 'package:aguas_monte_patria/services/meter_repository.dart';

void main() {
  late Directory dir;
  late ClientRecordsNotifier notifier;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hive_notifier_test');
    Hive.init(dir.path);
    Hive.registerAdapter(ClientMeterRecordAdapter(), override: true);
    notifier = ClientRecordsNotifier(MeterRepository());
    await notifier.loadClients(); // seeds sp-001 .. sp-010
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
}
