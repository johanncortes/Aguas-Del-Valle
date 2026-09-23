import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/client_meter_record.dart';

class ExcelExportService {
  /// Generate and save .xlsx file with all recorded readings
  Future<File> generateExcel(List<ClientMeterRecord> records) async {
    final excel = Excel.createExcel();

    // Remove default sheet and create our own
    excel.delete('Sheet1');
    final sheet = excel['Lecturas Monte Patria'];

    // Style for header row
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#1565C0'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
      fontSize: 12,
    );

    // Column headers
    final headers = [
      'ID Cliente',
      'Nombre Propietario',
      'Fecha/Hora Registro',
      'Lectura Hace 2 Meses',
      'Lectura Hace 1 Mes',
      'Lectura Actual',
      'Consumo M3',
      'Motivo No Lectura',
      'Observaciones',
    ];

    // Write header row
    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = headerStyle;
    }

    // Set column widths
    sheet.setColumnWidth(0, 15);
    sheet.setColumnWidth(1, 35);
    sheet.setColumnWidth(2, 22);
    sheet.setColumnWidth(3, 22);
    sheet.setColumnWidth(4, 20);
    sheet.setColumnWidth(5, 16);
    sheet.setColumnWidth(6, 14);
    sheet.setColumnWidth(7, 20);
    sheet.setColumnWidth(8, 40);

    // Data style
    final dataStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
      fontSize: 11,
    );

    final nameStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Left,
      fontSize: 11,
    );

    // Write data rows (only visited clients)
    final visitedRecords =
        records.where((r) => r.isVisited).toList()
          ..sort((a, b) => a.clientNumber.compareTo(b.clientNumber));

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    for (int i = 0; i < visitedRecords.length; i++) {
      final record = visitedRecords[i];
      final row = i + 1;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        ..value = TextCellValue(record.clientNumber)
        ..cellStyle = dataStyle;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        ..value = TextCellValue(record.ownerName)
        ..cellStyle = nameStyle;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
        ..value = TextCellValue(
          record.updatedAt != null
              ? dateFormat.format(record.updatedAt!)
              : '-',
        )
        ..cellStyle = dataStyle;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
        ..value = IntCellValue(record.readingTwoMonthsAgo)
        ..cellStyle = dataStyle;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
        ..value = IntCellValue(record.readingOneMonthAgo)
        ..cellStyle = dataStyle;

      // Visits without a reading leave reading and consumption blank
      // instead of exporting a misleading 0.
      final currentReading = record.currentReading;
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
        ..value = currentReading != null
            ? IntCellValue(currentReading)
            : TextCellValue('-')
        ..cellStyle = dataStyle;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
        ..value = currentReading != null
            ? IntCellValue(record.consumptionM3)
            : TextCellValue('-')
        ..cellStyle = dataStyle;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
        ..value = TextCellValue(record.nonReadingReason ?? '')
        ..cellStyle = dataStyle;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
        ..value = TextCellValue(record.observations ?? '')
        ..cellStyle = nameStyle;
    }

    // Save to documents directory
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = '${dir.path}/lecturas_monte_patria_$timestamp.xlsx';
    final fileBytes = excel.save();

    if (fileBytes == null) {
      throw Exception('Error al generar el archivo Excel');
    }

    final file = File(filePath);
    await file.writeAsBytes(fileBytes);
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
