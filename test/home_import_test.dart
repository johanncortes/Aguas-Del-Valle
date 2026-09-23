import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:aguas_monte_patria/models/client_meter_record.dart';
import 'package:aguas_monte_patria/providers/meter_providers.dart';
import 'package:aguas_monte_patria/screens/home_screen.dart';
import 'package:aguas_monte_patria/services/cached_tile_provider.dart';
import 'package:aguas_monte_patria/services/excel_import_service.dart';
import 'package:aguas_monte_patria/services/meter_repository.dart';

class _FakePathProvider extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      Directory.systemTemp.path;
}

class _FakeClientRecordsNotifier extends ClientRecordsNotifier {
  _FakeClientRecordsNotifier(List<ClientMeterRecord> records)
      : super(MeterRepository()) {
    state = records;
  }

  @override
  Future<void> loadClients() async {}

  @override
  Future<int> importClients(List<ClientMeterRecord> records) async {
    state = records;
    return records.length;
  }
}

class _FakeImportService extends ExcelImportService {
  _FakeImportService(this.result);

  /// Records to return, or an exception to throw.
  final Object? result;
  int calls = 0;

  @override
  Future<List<ClientMeterRecord>?> pickAndParse() async {
    calls++;
    if (result is Exception) throw result!;
    return result as List<ClientMeterRecord>?;
  }
}

ClientMeterRecord _client(String id, {int? reading}) => ClientMeterRecord(
      id: id,
      clientNumber: id,
      ownerName: 'Cliente $id',
      readingTwoMonthsAgo: 0,
      readingOneMonthAgo: 0,
      currentReading: reading,
      isVisited: reading != null,
      latitude: -30.73,
      longitude: -70.76,
    );

Future<_FakeImportService> _pumpHome(
  WidgetTester tester, {
  List<ClientMeterRecord> clients = const [],
  Object? importResult,
}) async {
  PathProviderPlatform.instance = _FakePathProvider();
  await tester.runAsync(CachedTileProvider.initialize);
  final service = _FakeImportService(importResult);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      clientRecordsProvider
          .overrideWith((ref) => _FakeClientRecordsNotifier(clients)),
      excelImportServiceProvider.overrideWithValue(service),
    ],
    child: const MaterialApp(home: HomeScreen()),
  ));
  await tester.pump(const Duration(milliseconds: 100));
  return service;
}

Future<void> _openImportFromMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Opciones'));
  await tester.pumpAndSettle();
  // The menu is on top of the empty-route card, which has the same label
  await tester.tap(find.text('Importar Ruta (Excel)').last);
  await tester.pumpAndSettle();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('empty route shows an import hint', (tester) async {
    await _pumpHome(tester);

    expect(find.text('No hay clientes cargados'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('importing from the menu replaces the route', (tester) async {
    final service = await _pumpHome(
      tester,
      importResult: [_client('a'), _client('b')],
    );

    await _openImportFromMenu(tester);
    expect(
      find.text('Esto borrará los datos actuales y cargará una nueva ruta. '
          '¿Continuar?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Elegir archivo'));
    await tester.pumpAndSettle();

    expect(service.calls, 1);
    expect(find.text('Se importaron 2 clientes.'), findsOneWidget);
    expect(find.text('No hay clientes cargados'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('cancelling the warning does not open the picker',
      (tester) async {
    final service = await _pumpHome(tester, importResult: [_client('a')]);

    await _openImportFromMenu(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(service.calls, 0);
    await _unmount(tester);
  });

  testWidgets('warns when visits would be lost', (tester) async {
    await _pumpHome(tester, clients: [_client('a', reading: 5), _client('b')]);

    await _openImportFromMenu(tester);
    expect(find.textContaining('Hay 1 visita(s) registradas'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('row errors are listed and the route is kept', (tester) async {
    await _pumpHome(
      tester,
      clients: [_client('a')],
      importResult: ExcelImportException(
        'El archivo tiene 1 fila(s) con errores. No se importó nada.',
        ['Fila 3: falta el nombre'],
      ),
    );

    await _openImportFromMenu(tester);
    await tester.tap(find.text('Elegir archivo'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo importar'), findsOneWidget);
    expect(find.text('• Fila 3: falta el nombre'), findsOneWidget);
    expect(find.text('No hay clientes cargados'), findsNothing);
    await _unmount(tester);
  });
}
