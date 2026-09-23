import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:aguas_monte_patria/models/client_meter_record.dart';

ClientMeterRecord _record({
  int? currentReading,
  bool isVisited = false,
  String? nonReadingReason,
  String? observations,
}) {
  return ClientMeterRecord(
    id: 'test-001',
    clientNumber: '12345',
    ownerName: 'Test User',
    readingTwoMonthsAgo: 100,
    readingOneMonthAgo: 120,
    currentReading: currentReading,
    isVisited: isVisited,
    latitude: -30.7,
    longitude: -70.7,
    updatedAt: isVisited ? DateTime(2026, 9, 1) : null,
    nonReadingReason: nonReadingReason,
    observations: observations,
  );
}

/// Writes records the way app versions before fields 10-11 did.
class _LegacyAdapter extends TypeAdapter<ClientMeterRecord> {
  @override
  final int typeId = 0;

  @override
  ClientMeterRecord read(BinaryReader reader) => throw UnimplementedError();

  @override
  void write(BinaryWriter writer, ClientMeterRecord obj) {
    final values = [
      obj.id, obj.clientNumber, obj.ownerName, obj.readingTwoMonthsAgo,
      obj.readingOneMonthAgo, obj.currentReading, obj.isVisited,
      obj.latitude, obj.longitude, obj.updatedAt,
    ];
    writer.writeByte(values.length);
    for (var i = 0; i < values.length; i++) {
      writer.writeByte(i);
      writer.write(values[i]);
    }
  }
}

void main() {
  group('startNewCycle', () {
    test('shifts history when there is a new reading', () {
      final next = _record(
        currentReading: 145,
        isVisited: true,
        observations: 'ok',
      ).copyWith(readingLatitude: -30.7, readingLongitude: -70.7)
          .startNewCycle();

      expect(next.readingTwoMonthsAgo, 120);
      expect(next.readingOneMonthAgo, 145);
      expect(next.currentReading, isNull);
      expect(next.isVisited, isFalse);
      expect(next.updatedAt, isNull);
      expect(next.observations, isNull);
      expect(next.readingLatitude, isNull);
      expect(next.readingLongitude, isNull);
    });

    test('keeps history intact for a client that was not visited', () {
      final next = _record().startNewCycle();

      expect(next.readingTwoMonthsAgo, 100);
      expect(next.readingOneMonthAgo, 120);
      expect(next.isVisited, isFalse);
    });

    test('keeps history and clears reason for a visit without reading', () {
      final next = _record(
        isVisited: true,
        nonReadingReason: NonReadingReason.dog.label,
      ).startNewCycle();

      expect(next.readingTwoMonthsAgo, 100);
      expect(next.readingOneMonthAgo, 120);
      expect(next.isVisited, isFalse);
      expect(next.nonReadingReason, isNull);
    });
  });

  group('visitStatus', () {
    test('pending when not visited', () {
      expect(_record().visitStatus, VisitStatus.pending);
    });

    test('read when visited with a reading', () {
      expect(_record(currentReading: 145, isVisited: true).visitStatus,
          VisitStatus.read);
    });

    test('noReading when visited with a non-reading reason', () {
      expect(
        _record(isVisited: true, nonReadingReason: 'Perro').visitStatus,
        VisitStatus.noReading,
      );
    });
  });

  group('ClientMeterRecordAdapter', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('hive_test');
      Hive.init(dir.path);
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });

    test('round-trips the new fields', () async {
      Hive.registerAdapter(ClientMeterRecordAdapter(), override: true);
      final box = await Hive.openBox<ClientMeterRecord>('records');
      await box.put('a', _record(
        isVisited: true,
        nonReadingReason: NonReadingReason.houseClosed.label,
        observations: 'Volver el lunes',
      ).copyWith(readingLatitude: -30.7296, readingLongitude: -70.7644));
      await box.close();

      final reopened = await Hive.openBox<ClientMeterRecord>('records');
      final record = reopened.get('a')!;
      expect(record.nonReadingReason, 'Casa cerrada');
      expect(record.observations, 'Volver el lunes');
      expect(record.hasNonReading, isTrue);
      expect(record.readingLatitude, -30.7296);
      expect(record.readingLongitude, -70.7644);
    });

    test('reads records saved before the new fields existed', () async {
      Hive.registerAdapter(_LegacyAdapter(), override: true);
      final box = await Hive.openBox<ClientMeterRecord>('records');
      await box.put('a', _record(currentReading: 145, isVisited: true));
      await box.close();

      Hive.registerAdapter(ClientMeterRecordAdapter(), override: true);
      final reopened = await Hive.openBox<ClientMeterRecord>('records');
      final record = reopened.get('a')!;
      expect(record.currentReading, 145);
      expect(record.nonReadingReason, isNull);
      expect(record.observations, isNull);
      expect(record.readingLatitude, isNull);
      expect(record.readingLongitude, isNull);
    });
  });
}
