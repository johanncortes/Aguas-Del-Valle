import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/client_meter_record.dart';

/// One exported column: header, width and how to fill each row.
typedef _ExportColumn = ({
  String header,
  double width,
  CellValue Function(ClientMeterRecord record) value,
  bool leftAligned,
});

class ExcelExportService {
  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  /// Columns of the exported sheet. The first ones (N° Cliente, Nombre,
  /// Latitud, Longitud, the readings) are the ones the route import
  /// reads, so an exported file can be imported as next month's route.
  static final List<_ExportColumn> _columns = [
    _text('N° Cliente', 15, (r) => r.clientNumber),
    _text('Nombre Propietario', 35, (r) => r.ownerName, leftAligned: true),
    _number('Latitud', 14, (r) => r.latitude),
    _number('Longitud', 14, (r) => r.longitude),
    _text('Estado', 14, (r) => switch (r.visitStatus) {
          VisitStatus.pending => 'Pendiente',
          VisitStatus.read => 'Leído',
          VisitStatus.noReading => 'Sin lectura',
        }),
    _text('Fecha/Hora Registro', 22,
        (r) => r.updatedAt != null ? _dateFormat.format(r.updatedAt!) : '-'),
    _int('Lectura Hace 2 Meses', 22, (r) => r.readingTwoMonthsAgo),
    _int('Lectura Hace 1 Mes', 20, (r) => r.readingOneMonthAgo),
    // Visits without a reading leave reading and consumption as "-"
    // instead of exporting a misleading 0.
    _int('Lectura Actual', 16, (r) => r.currentReading),
    _int('Consumo M3', 14,
        (r) => r.currentReading != null ? r.consumptionM3 : null),
    _text('Motivo No Lectura', 20, (r) => r.nonReadingReason ?? ''),
    _text('Observaciones', 40, (r) => r.observations ?? '',
        leftAligned: true),
    // Where the reader was when saving the visit (GPS audit)
    _number('Latitud Lectura', 16, (r) => r.readingLatitude),
    _number('Longitud Lectura', 16, (r) => r.readingLongitude),
    // Evidence photos stay on the phone (evidence_photos folder); the
    // file name links each one to its row.
    _text('Foto', 30, (r) => r.photoPath?.split('/').last ?? ''),
  ];

  static _ExportColumn _text(
    String header,
    double width,
    String Function(ClientMeterRecord) value, {
    bool leftAligned = false,
  }) =>
      (
        header: header,
        width: width,
        value: (r) => TextCellValue(value(r)),
        leftAligned: leftAligned,
      );

  static _ExportColumn _int(
          String header, double width, int? Function(ClientMeterRecord) value) =>
      (
        header: header,
        width: width,
        value: (r) {
          final v = value(r);
          return v != null ? IntCellValue(v) : TextCellValue('-');
        },
        leftAligned: false,
      );

  static _ExportColumn _number(String header, double width,
          double? Function(ClientMeterRecord) value) =>
      (
        header: header,
        width: width,
        value: (r) {
          final v = value(r);
          return v != null ? DoubleCellValue(v) : TextCellValue('-');
        },
        leftAligned: false,
      );

  /// Builds the .xlsx with every client of the route (pending ones
  /// included, so the file is a complete route), sorted by client number.
  List<int> buildExcelBytes(List<ClientMeterRecord> records) {
    final excel = Excel.createExcel();

    // Rename the default sheet: delete() is a no-op on a workbook's only
    // sheet, which used to leave an empty "Sheet1" as the first sheet.
    const sheetName = 'Lecturas Monte Patria';
    excel.rename(excel.getDefaultSheet()!, sheetName);
    final sheet = excel[sheetName];

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#1565C0'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
      fontSize: 12,
    );
    final dataStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
      fontSize: 11,
    );
    final leftStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Left,
      fontSize: 11,
    );

    for (var col = 0; col < _columns.length; col++) {
      sheet.setColumnWidth(col, _columns[col].width);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
        ..value = TextCellValue(_columns[col].header)
        ..cellStyle = headerStyle;
    }

    final sorted = [...records]..sort(_compareClientNumbers);
    for (var i = 0; i < sorted.length; i++) {
      for (var col = 0; col < _columns.length; col++) {
        final column = _columns[col];
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: i + 1))
          ..value = column.value(sorted[i])
          ..cellStyle = column.leftAligned ? leftStyle : dataStyle;
      }
    }

    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Error al generar el archivo Excel');
    }
    return bytes;
  }

  /// Numeric order when both numbers are numeric ("20" before "100").
  static int _compareClientNumbers(ClientMeterRecord a, ClientMeterRecord b) {
    final na = int.tryParse(a.clientNumber);
    final nb = int.tryParse(b.clientNumber);
    if (na != null && nb != null) return na.compareTo(nb);
    return a.clientNumber.compareTo(b.clientNumber);
  }

  /// Generate and save the .xlsx file in the app documents directory.
  Future<File> generateExcel(List<ClientMeterRecord> records) async {
    final bytes = buildExcelBytes(records);
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/lecturas_monte_patria_$timestamp.xlsx');
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Share the generated file via OS native share dialog
  Future<void> shareFile(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Lecturas de Medidores - Monte Patria',
      text: 'Archivo de lecturas de medidores de agua generado desde Aguas Monte Patria.',
    );
  }
}
