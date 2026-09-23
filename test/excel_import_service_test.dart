import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aguas_monte_patria/services/excel_import_service.dart';

const _headers = [
  'N° Cliente',
  'Nombre',
  'Latitud',
  'Longitud',
  'Lectura Mes Anterior',
  'Lectura 2 Meses Atrás',
];

/// Builds an .xlsx file whose first sheet contains [rows].
List<int> _xlsx(List<List<Object?>> rows) {
  final excel = Excel.createExcel();
  final sheet = excel[excel.getDefaultSheet()!];
  for (var r = 0; r < rows.length; r++) {
    for (var c = 0; c < rows[r].length; c++) {
      final value = rows[r][c];
      if (value == null) continue;
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
          .value = switch (value) {
        int() => IntCellValue(value),
        double() => DoubleCellValue(value),
        _ => TextCellValue('$value'),
      };
    }
  }
  return excel.save()!;
}

ExcelImportException _parseError(List<int> bytes) {
  try {
    ExcelImportService().parse(bytes);
  } on ExcelImportException catch (e) {
    return e;
  }
  fail('Expected an ExcelImportException');
}

void main() {
  final service = ExcelImportService();

  test('imports a well-formed route', () {
    final records = service.parse(_xlsx([
      _headers,
      [40225001, 'María Cortés', -30.728, -70.766, 1268, 1245],
      ['40225002', 'José Araya', '-30,73', '-70,764', '912', '890'],
    ]));

    expect(records, hasLength(2));
    final maria = records[0];
    expect(maria.clientNumber, '40225001');
    expect(maria.ownerName, 'María Cortés');
    expect(maria.latitude, -30.728);
    expect(maria.longitude, -70.766);
    expect(maria.readingOneMonthAgo, 1268);
    expect(maria.readingTwoMonthsAgo, 1245);
    expect(maria.isVisited, isFalse);
    expect(maria.currentReading, isNull);

    // Text cells with Chilean decimal commas
    expect(records[1].latitude, -30.73);
    expect(records[1].readingOneMonthAgo, 912);
    expect(records[0].id, isNot(records[1].id));
  });

  test('finds the header below a title, in any column order, and '
      'accepts header variants', () {
    final records = service.parse(_xlsx([
      ['Ruta Sol de las Praderas - Octubre'],
      [],
      ['nombre propietario', 'LATITUD', 'longitud', 'Nro. Cliente',
          'Lectura Hace 2 Meses', 'Lectura Hace 1 Mes'],
      ['Pedro Tapia', -30.73, -70.76, 40225004, 567, 582],
    ]));

    expect(records.single.clientNumber, '40225004');
    expect(records.single.readingTwoMonthsAgo, 567);
    expect(records.single.readingOneMonthAgo, 582);
  });

  test('skips blank rows and treats empty readings as 0', () {
    final records = service.parse(_xlsx([
      _headers,
      [1, 'A', -30.7, -70.7, null, null],
      [],
      [2, 'B', -30.7, -70.7, 10, 5],
    ]));

    expect(records, hasLength(2));
    expect(records[0].readingOneMonthAgo, 0);
    expect(records[0].readingTwoMonthsAgo, 0);
  });

  test('reads an optional Sector column', () {
    final records = service.parse(_xlsx([
      [..._headers, 'Sector'],
      [1, 'A', -30.7, -70.7, 10, 5, 'Varillar'],
      [2, 'B', -30.7, -70.7, 10, 5, null],
    ]));

    expect(records[0].sector, 'Varillar');
    expect(records[1].sector, isNull);
  });

  test('coordinates are optional but never half filled', () {
    final records = service.parse(_xlsx([
      _headers,
      [1, 'Sin coordenadas', null, null, 10, 5],
      [2, 'Exportado sin ubicación', '-', '-', 10, 5],
    ]));
    expect(records.map((r) => r.hasLocation), [false, false]);

    final error = _parseError(_xlsx([
      _headers,
      [1, 'A', -30.7, null, 10, 5],
      [2, 'B', null, -70.7, 10, 5],
    ]));
    expect(error.rowErrors, [
      'Fila 2: falta la longitud',
      'Fila 3: falta la latitud',
    ]);
  });

  test('reports missing columns by name', () {
    final error = _parseError(_xlsx([
      ['N° Cliente', 'Nombre', 'Latitud'],
      [1, 'A', -30.7],
    ]));

    expect(error.message, contains('Longitud'));
    expect(error.message, contains('Lectura Mes Anterior'));
    expect(error.message, contains('Lectura 2 Meses Atrás'));
    expect(error.message, isNot(contains('Nombre,')));
  });

  test('rejects a sheet without a recognizable header', () {
    final error = _parseError(_xlsx([
      ['hola', 'mundo'],
      [1, 2],
    ]));
    expect(error.message, contains('encabezados'));
  });

  test('lists every invalid row with its Excel row number', () {
    final error = _parseError(_xlsx([
      _headers,
      [1, 'Válido', -30.7, -70.7, 10, 5],
      [2, '', -30.7, -70.7, 10, 5], // row 3: no name
      [3, 'C', 'abc', -70.7, 10, 5], // row 4: bad latitude
      [4, 'D', -30.7, -70.7, 5, 10], // row 5: negative history
      [1, 'E', -30.7, -70.7, 10, 5], // row 6: duplicate of row 2
      [6, 'F', -30.7, -70.7, -3, 0], // row 7: negative reading
    ]));

    expect(error.message, contains('5 fila(s) con errores'));
    expect(error.rowErrors, [
      'Fila 3: falta el nombre',
      'Fila 4: latitud inválida',
      'Fila 5: la lectura del mes anterior es menor que la de 2 meses atrás',
      'Fila 6: N° de cliente 1 repetido (fila 2)',
      'Fila 7: lectura mes anterior inválida',
    ]);
  });

  test('rejects a file with headers but no clients', () {
    final error = _parseError(_xlsx([_headers]));
    expect(error.message, 'El archivo no contiene clientes.');
  });

  test('rejects files that are not .xlsx', () {
    final error = _parseError('<html>no es excel</html>'.codeUnits);
    expect(error.message, contains('.xlsx'));
  });
}
