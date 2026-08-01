import 'package:flutter_test/flutter_test.dart';
import 'package:aguas_monte_patria/models/client_meter_record.dart';

void main() {
  group('ClientMeterRecord', () {
    test('consumptionM3 calculates correctly', () {
      final record = ClientMeterRecord(
        id: 'test-001',
        clientNumber: '12345',
        ownerName: 'Test User',
        readingTwoMonthsAgo: 100,
        readingOneMonthAgo: 120,
        currentReading: 145,
        latitude: -30.695,
        longitude: -70.957,
      );

      expect(record.consumptionM3, 25); // 145 - 120
    });

    test('consumptionM3 returns 0 when no current reading', () {
      final record = ClientMeterRecord(
        id: 'test-002',
        clientNumber: '12346',
        ownerName: 'Test User 2',
        readingTwoMonthsAgo: 100,
        readingOneMonthAgo: 120,
        latitude: -30.695,
        longitude: -70.957,
      );

      expect(record.consumptionM3, 0);
    });

    test('hasReadingWarning detects lower current reading', () {
      final record = ClientMeterRecord(
        id: 'test-003',
        clientNumber: '12347',
        ownerName: 'Test User 3',
        readingTwoMonthsAgo: 100,
        readingOneMonthAgo: 120,
        currentReading: 110,
        latitude: -30.695,
        longitude: -70.957,
      );

      expect(record.hasReadingWarning, true);
    });

    test('hasReadingWarning is false for valid reading', () {
      final record = ClientMeterRecord(
        id: 'test-004',
        clientNumber: '12348',
        ownerName: 'Test User 4',
        readingTwoMonthsAgo: 100,
        readingOneMonthAgo: 120,
        currentReading: 145,
        latitude: -30.695,
        longitude: -70.957,
      );

      expect(record.hasReadingWarning, false);
    });

    test('copyWith creates new instance with updated fields', () {
      final record = ClientMeterRecord(
        id: 'test-005',
        clientNumber: '12349',
        ownerName: 'Test User 5',
        readingTwoMonthsAgo: 100,
        readingOneMonthAgo: 120,
        latitude: -30.695,
        longitude: -70.957,
      );

      final updated = record.copyWith(
        currentReading: 150,
        isVisited: true,
      );

      expect(updated.currentReading, 150);
      expect(updated.isVisited, true);
      expect(updated.ownerName, 'Test User 5'); // unchanged
    });

    test('Dynamic client record defaults isVisited to false without current reading', () {
      final record = ClientMeterRecord(
        id: 'dyn-001',
        clientNumber: '40225099',
        ownerName: 'Cliente Dinámico Sol de las Praderas',
        readingTwoMonthsAgo: 0,
        readingOneMonthAgo: 0,
        currentReading: null,
        isVisited: false,
        latitude: -30.729639,
        longitude: -70.764389,
      );

      expect(record.isVisited, false);
      expect(record.latitude, -30.729639);
      expect(record.longitude, -70.764389);
      expect(record.consumptionM3, 0);
    });

    test('Dynamic client record with current reading sets isVisited to true', () {
      final record = ClientMeterRecord(
        id: 'dyn-002',
        clientNumber: '40225100',
        ownerName: 'Cliente Dinámico con Lectura',
        readingTwoMonthsAgo: 10,
        readingOneMonthAgo: 20,
        currentReading: 35,
        isVisited: true,
        latitude: -30.729639,
        longitude: -70.764389,
      );

      expect(record.isVisited, true);
      expect(record.consumptionM3, 15);
    });
  });
}
