import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aguas_monte_patria/models/client_meter_record.dart';
import 'package:aguas_monte_patria/services/excel_export_service.dart';
import 'package:aguas_monte_patria/services/excel_import_service.dart';

ClientMeterRecord _client(
  String number, {
  int? reading,
  String? reason,
  double? readingLat,
  double? readingLng,
}) =>
    ClientMeterRecord(
      id: 'id-$number',
      clientNumber: number,
      ownerName: 'Cliente $number',
      readingTwoMonthsAgo: 100,
      readingOneMonthAgo: 120,
      currentReading: reading,
      isVisited: reading != null || reason != null,
      latitude: -30.7280,
      longitude: -70.7660,
      updatedAt: reading != null || reason != null ? DateTime(2026, 9, 1) : null,
      nonReadingReason: reason,
      readingLatitude: readingLat,
      readingLongitude: readingLng,
      photoPath: reading == 145 ? '/docs/evidence_photos/id-100_1.jpg' : null,
    );

/// Rows of the first sheet as display strings.
List<List<String>> _rows(List<int> bytes) {
  final sheet = Excel.decodeBytes(bytes).tables.values.first;
  return [
    for (final row in sheet.rows)
      [for (final cell in row) cell?.value?.toString() ?? ''],
  ];
}

void main() {
  final route = [
    _client('100', reading: 145, readingLat: -30.7281, readingLng: -70.7662),
    _client('20'), // pending
    _client('3', reason: 'Perro'),
    _client('4', reading: 110), // lower reading confirmed by the reader
  ];

  test('the data is on the only sheet', () {
    final excel =
        Excel.decodeBytes(ExcelExportService().buildExcelBytes(route));
    expect(excel.tables.keys, ['Lecturas Monte Patria']);
  });

  test('exports every client with master and reading coordinates', () {
    final rows = _rows(ExcelExportService().buildExcelBytes(route));

    expect(rows.first, [
      'N° Cliente', 'Nombre Propietario', 'Latitud', 'Longitud', 'Estado',
      'Fecha/Hora Registro', 'Lectura Hace 2 Meses', 'Lectura Hace 1 Mes',
      'Lectura Actual', 'Consumo M3', 'Motivo No Lectura', 'Observaciones',
      'Latitud Lectura', 'Longitud Lectura', 'Foto',
    ]);
    // All clients, including pending, in numeric client-number order
    expect(rows.skip(1).map((r) => r[0]), ['3', '4', '20', '100']);

    final read = rows.last;
    expect(read.sublist(2, 5), ['-30.728', '-70.766', 'Leído']);
    expect(read.sublist(8, 10), ['145', '25']);
    expect(read.sublist(12), ['-30.7281', '-70.7662', 'id-100_1.jpg']);

    final pending = rows[3];
    expect(pending[4], 'Pendiente');
    expect(pending.sublist(8, 10), ['-', '-']);
    expect(pending.sublist(12), ['-', '-', '']); // no GPS, no photo

    expect(rows[1].sublist(4, 5), ['Sin lectura']);
    expect(rows[1][10], 'Perro');
  });

  test('an exported file imports as next month\'s route', () {
    final bytes = ExcelExportService().buildExcelBytes(route);
    final next = {
      for (final r in ExcelImportService().parse(bytes)) r.clientNumber: r,
    };

    expect(next.keys, unorderedEquals(['100', '20', '3', '4']));

    // Read: this month's reading becomes "mes anterior"
    expect(next['100']!.readingOneMonthAgo, 145);
    expect(next['100']!.readingTwoMonthsAgo, 120);
    // Not read (pending or with a reason): history kept
    expect(next['20']!.readingOneMonthAgo, 120);
    expect(next['20']!.readingTwoMonthsAgo, 100);
    expect(next['3']!.readingOneMonthAgo, 120);
    // A confirmed lower reading (e.g. meter rollover) is not rejected
    expect(next['4']!.readingOneMonthAgo, 110);
    expect(next['4']!.readingTwoMonthsAgo, 120);

    // Master coordinates carried over; the new cycle starts clean
    for (final r in next.values) {
      expect(r.latitude, -30.7280);
      expect(r.longitude, -70.7660);
      expect(r.isVisited, isFalse);
      expect(r.currentReading, isNull);
      expect(r.readingLatitude, isNull);
    }
  });
}
