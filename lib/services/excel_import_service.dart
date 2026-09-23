import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/client_meter_record.dart';
import '../utils/text_normalize.dart';

/// Thrown when a route file can't be read or has invalid content.
class ExcelImportException implements Exception {
  final String message;

  /// Per-row problems ("Fila 5: ..."), empty for file-level errors.
  final List<String> rowErrors;

  ExcelImportException(this.message, [this.rowErrors = const []]);

  @override
  String toString() =>
      rowErrors.isEmpty ? message : '$message\n${rowErrors.join('\n')}';
}

/// The columns a route file must have, with the header names accepted for
/// each. Headers are matched ignoring case, accents, "°" and extra spaces,
/// so the app's own export headers are accepted too.
enum _Column {
  clientNumber('N° Cliente', ['n cliente', 'no cliente', 'nro cliente',
      'numero cliente', 'numero de cliente', 'id cliente']),
  ownerName('Nombre', ['nombre', 'nombre propietario', 'propietario']),
  latitude('Latitud', ['latitud', 'lat']),
  longitude('Longitud', ['longitud', 'lng', 'lon']),
  readingOneMonthAgo('Lectura Mes Anterior', ['lectura mes anterior',
      'lectura hace 1 mes', 'lectura 1 mes atras']),
  readingTwoMonthsAgo('Lectura 2 Meses Atrás', ['lectura 2 meses atras',
      'lectura hace 2 meses']);

  const _Column(this.displayName, this.aliases);
  final String displayName;
  final List<String> aliases;
}

/// Optional "Lectura Actual" column, present in files exported by the app.
/// When a row has a value there, the route is rolled over to the next
/// month on import (same rule as closing the month in the app).
const _currentReadingAliases = ['lectura actual'];

/// Reads the monthly route (list of clients) from an .xlsx file.
class ExcelImportService {
  static const _uuid = Uuid();

  /// How many rows at the top are searched for the header row, so files
  /// with a title above the table still work.
  static const _headerSearchRows = 10;

  /// Maximum row errors listed in the exception.
  static const _maxRowErrors = 10;

  /// Opens the system file picker and parses the chosen file.
  /// Returns null if the user cancels.
  Future<List<ClientMeterRecord>?> pickAndParse() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null) return null; // cancelled
    final bytes = result.files.single.bytes;
    if (bytes == null) {
      throw ExcelImportException('No se pudo leer el archivo seleccionado.');
    }
    return parse(bytes);
  }

  /// Parses an .xlsx file. Either every row is valid and all clients are
  /// returned, or an [ExcelImportException] is thrown and nothing is
  /// imported.
  List<ClientMeterRecord> parse(List<int> bytes) {
    final Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (_) {
      throw ExcelImportException(
          'No se pudo abrir el archivo. Debe ser un Excel .xlsx '
          '(los .xls antiguos no son compatibles).');
    }

    for (final sheet in excel.tables.values) {
      final rows = sheet.rows;
      final header = _findHeader(rows);
      if (header != null) {
        return _parseRows(
          rows,
          header.rowIndex,
          header.columns,
          _findColumn(rows[header.rowIndex], _currentReadingAliases),
        );
      }
    }

    throw ExcelImportException(
      'No se encontró la fila de encabezados. El archivo debe tener las '
      'columnas: ${_Column.values.map((c) => c.displayName).join(', ')}.',
    );
  }

  /// Finds the first row (among the top rows) containing every required
  /// column. Throws if a row has some columns but not all, so the office
  /// is told exactly which ones are missing.
  ({int rowIndex, Map<_Column, int> columns})? _findHeader(
      List<List<Data?>> rows) {
    Map<_Column, int>? bestPartial;

    for (var r = 0; r < rows.length && r < _headerSearchRows; r++) {
      final columns = <_Column, int>{};
      for (var c = 0; c < rows[r].length; c++) {
        final text = _normalizeHeader(_cellText(rows[r][c]));
        if (text.isEmpty) continue;
        for (final column in _Column.values) {
          if (!columns.containsKey(column) && column.aliases.contains(text)) {
            columns[column] = c;
          }
        }
      }
      if (columns.length == _Column.values.length) {
        return (rowIndex: r, columns: columns);
      }
      if (columns.length >= 2 &&
          columns.length > (bestPartial?.length ?? 0)) {
        bestPartial = columns;
      }
    }

    if (bestPartial != null) {
      final missing = _Column.values
          .where((c) => !bestPartial!.containsKey(c))
          .map((c) => c.displayName);
      throw ExcelImportException(
          'Faltan columnas en el archivo: ${missing.join(', ')}.');
    }
    return null;
  }

  static int? _findColumn(List<Data?> headerRow, List<String> aliases) {
    for (var c = 0; c < headerRow.length; c++) {
      if (aliases.contains(_normalizeHeader(_cellText(headerRow[c])))) {
        return c;
      }
    }
    return null;
  }

  List<ClientMeterRecord> _parseRows(
    List<List<Data?>> rows,
    int headerRow,
    Map<_Column, int> columns,
    int? currentReadingColumn,
  ) {
    final records = <ClientMeterRecord>[];
    final errors = <String>[];
    final seenNumbers = <String, int>{}; // client number -> Excel row

    for (var r = headerRow + 1; r < rows.length; r++) {
      final row = rows[r];
      Data? cell(_Column column) {
        final index = columns[column]!;
        return index < row.length ? row[index] : null;
      }

      // Skip fully blank rows (common at the end of office files)
      if (_Column.values.every((c) => _cellText(cell(c)).isEmpty)) continue;

      final excelRow = r + 1; // 1-based, as shown in Excel
      final rowErrors = <String>[];

      final clientNumber = _cellText(cell(_Column.clientNumber));
      final ownerName = _cellText(cell(_Column.ownerName));
      final latitude = _cellNumber(cell(_Column.latitude));
      final longitude = _cellNumber(cell(_Column.longitude));
      var oneMonth = _cellReading(cell(_Column.readingOneMonthAgo));
      var twoMonths = _cellReading(cell(_Column.readingTwoMonthsAgo));

      // Exported files carry this month's reading: roll it into the
      // history. "-" or empty means the client was not read; its
      // history is kept as is.
      final currentCell =
          currentReadingColumn != null && currentReadingColumn < row.length
              ? row[currentReadingColumn]
              : null;
      final currentText = _cellText(currentCell);
      final hasCurrentReading = currentText.isNotEmpty && currentText != '-';
      final currentReading =
          hasCurrentReading ? _cellReading(currentCell) : null;

      if (clientNumber.isEmpty) rowErrors.add('falta el N° de cliente');
      if (ownerName.isEmpty) rowErrors.add('falta el nombre');
      if (latitude == null || latitude < -90 || latitude > 90) {
        rowErrors.add('latitud inválida');
      }
      if (longitude == null || longitude < -180 || longitude > 180) {
        rowErrors.add('longitud inválida');
      }
      if (oneMonth == null) rowErrors.add('lectura mes anterior inválida');
      if (twoMonths == null) rowErrors.add('lectura 2 meses atrás inválida');
      if (hasCurrentReading && currentReading == null) {
        rowErrors.add('lectura actual inválida');
      }
      if (currentReading != null && oneMonth != null) {
        // A lower reading here was already confirmed by the reader in the
        // app (typo check or meter rollover), so it isn't rejected.
        twoMonths = oneMonth;
        oneMonth = currentReading;
      } else if (oneMonth != null &&
          twoMonths != null &&
          oneMonth < twoMonths) {
        rowErrors.add('la lectura del mes anterior es menor que la de '
            '2 meses atrás');
      }
      final firstRow = seenNumbers[clientNumber];
      if (clientNumber.isNotEmpty && firstRow != null) {
        rowErrors.add('N° de cliente $clientNumber repetido (fila $firstRow)');
      }

      if (rowErrors.isNotEmpty) {
        errors.add('Fila $excelRow: ${rowErrors.join(', ')}');
        continue;
      }

      seenNumbers[clientNumber] = excelRow;
      records.add(ClientMeterRecord(
        id: 'imp-${_uuid.v4()}',
        clientNumber: clientNumber,
        ownerName: ownerName,
        readingTwoMonthsAgo: twoMonths!,
        readingOneMonthAgo: oneMonth!,
        latitude: latitude!,
        longitude: longitude!,
      ));
    }

    if (errors.isNotEmpty) {
      final shown = errors.take(_maxRowErrors).toList();
      if (errors.length > shown.length) {
        shown.add('… y ${errors.length - shown.length} fila(s) más');
      }
      throw ExcelImportException(
          'El archivo tiene ${errors.length} fila(s) con errores. '
          'No se importó nada.',
          shown);
    }
    if (records.isEmpty) {
      throw ExcelImportException('El archivo no contiene clientes.');
    }
    return records;
  }

  static String _cellText(Data? data) {
    final value = data?.value;
    return switch (value) {
      null => '',
      TextCellValue() => value.value.toString().trim(),
      // Client numbers typed as numbers come back as ints/doubles
      IntCellValue() => '${value.value}',
      DoubleCellValue() => value.value == value.value.truncateToDouble()
          ? '${value.value.toInt()}'
          : '${value.value}',
      _ => value.toString().trim(),
    };
  }

  /// Accepts numeric cells and text cells, including Chilean decimal
  /// commas ("-30,7296").
  static double? _cellNumber(Data? data) {
    final value = data?.value;
    return switch (value) {
      IntCellValue() => value.value.toDouble(),
      DoubleCellValue() => value.value,
      _ => double.tryParse(_cellText(data).replaceAll(',', '.')),
    };
  }

  /// Readings are non-negative whole numbers; an empty cell counts as 0
  /// (new connection without history). Returns null when invalid.
  static int? _cellReading(Data? data) {
    if (_cellText(data).isEmpty) return 0;
    final number = _cellNumber(data);
    if (number == null || number < 0 || number != number.truncate()) {
      return null;
    }
    return number.toInt();
  }

  /// "N° Cliente" -> "n cliente", "Lectura 2 Meses Atrás" ->
  /// "lectura 2 meses atras".
  static String _normalizeHeader(String text) {
    return normalizeForSearch(text)
        .replaceAll(RegExp(r'[°º.#:]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
