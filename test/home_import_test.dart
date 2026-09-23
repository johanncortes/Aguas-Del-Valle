import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:aguas_monte_patria/models/client_meter_record.dart';
import 'package:aguas_monte_patria/providers/client_list_providers.dart';
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

  @override
  Future<void> updateClientLocation(
      String clientId, double newLat, double newLng) async {
    state = [
      for (final c in state)
        c.id == clientId ? c.copyWith(latitude: newLat, longitude: newLng) : c,
    ];
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

ClientMeterRecord _client(String id, {int? reading, bool located = true}) =>
    ClientMeterRecord(
      id: id,
      clientNumber: id,
      ownerName: 'Cliente $id',
      readingTwoMonthsAgo: 0,
      readingOneMonthAgo: 0,
      currentReading: reading,
      isVisited: reading != null,
      latitude: located ? -30.73 : null,
      longitude: located ? -70.76 : null,
    );

Future<_FakeImportService> _pumpHome(
  WidgetTester tester, {
  List<ClientMeterRecord> clients = const [],
  Object? importResult,
  Size? screen,
  String? pickingClientId,
}) async {
  if (screen != null) {
    tester.view.physicalSize = screen * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }
  PathProviderPlatform.instance = _FakePathProvider();
  await tester.runAsync(CachedTileProvider.initialize);
  final service = _FakeImportService(importResult);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      clientRecordsProvider
          .overrideWith((ref) => _FakeClientRecordsNotifier(clients)),
      excelImportServiceProvider.overrideWithValue(service),
      if (pickingClientId != null)
        locationPickerClientProvider.overrideWith((ref) => pickingClientId),
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

  testWidgets('export button is hidden on an empty route', (tester) async {
    await _pumpHome(tester);
    expect(find.text('Exportar Excel'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('export button is shown when there are clients',
      (tester) async {
    await _pumpHome(tester, clients: [_client('a')]);
    expect(find.text('Exportar Excel'), findsOneWidget);
    await _unmount(tester);
  });

  for (final (name, screen) in [
    ('iPhone SE', const Size(375, 667)),
    ('iPhone 14', const Size(390, 844)),
  ]) {
    testWidgets('empty-route card does not overlap the map controls '
        'on $name', (tester) async {
      await _pumpHome(tester, screen: screen);

      final card = tester.getRect(find.byKey(const Key('emptyRouteCard')));
      for (final tooltip in ['Agregar cliente', 'Mi ubicación',
          'Centrar mapa']) {
        final control = tester.getRect(find.byTooltip(tooltip));
        expect(card.overlaps(control), isFalse, reason: tooltip);
      }
      expect(tester.takeException(), isNull); // no overflow
      await _unmount(tester);
    });
  }

  testWidgets('clients without location get no pin and a banner',
      (tester) async {
    await _pumpHome(tester, clients: [
      _client('a', located: false),
      _client('b', located: false),
    ]);

    // Pending pins use the water drop icon; only the header logo remains
    expect(find.byIcon(Icons.water_drop), findsOneWidget);
    expect(find.text('2 clientes sin ubicación en el mapa. '
        'Búsquelos en la lista para fijarla.'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('located clients keep their pin and there is no banner',
      (tester) async {
    await _pumpHome(tester, clients: [_client('a')]);

    expect(find.byIcon(Icons.water_drop), findsNWidgets(2)); // logo + pin
    expect(find.byKey(const Key('unlocatedBanner')), findsNothing);
    await _unmount(tester);
  });

  group('location picker mode', () {
    final clients = [
      _client('a', located: false),
      _client('b'),
    ];

    ProviderContainer container(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));

    testWidgets('shows the crosshair and panel and hides the normal UI',
        (tester) async {
      await _pumpHome(tester, clients: clients, pickingClientId: 'a');

      expect(find.byKey(const Key('locationPickerCrosshair')), findsOneWidget);
      expect(find.text('Mueve el mapa para ubicar a Cliente a'),
          findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Confirmar Ubicación'), findsOneWidget);

      expect(find.byTooltip('Agregar cliente'), findsNothing);
      expect(find.text('Exportar Excel'), findsNothing);
      expect(find.text('Progreso de Ruta'), findsNothing);
      expect(find.byKey(const Key('unlocatedBanner')), findsNothing);
      await _unmount(tester);
    });

    testWidgets('the crosshair ignores touches', (tester) async {
      await _pumpHome(tester, clients: clients, pickingClientId: 'a');

      final ignorePointer = tester.widget<IgnorePointer>(find.ancestor(
        of: find.byKey(const Key('locationPickerCrosshair')),
        matching: find.byType(IgnorePointer),
      ).first);
      expect(ignorePointer.ignoring, isTrue);
      await _unmount(tester);
    });

    testWidgets('Cancelar leaves picker mode without saving', (tester) async {
      await _pumpHome(tester, clients: clients, pickingClientId: 'a');

      await tester.tap(find.text('Cancelar'));
      await tester.pump();

      expect(container(tester).read(locationPickerClientProvider), isNull);
      expect(find.byKey(const Key('locationPickerCrosshair')), findsNothing);
      expect(find.text('Progreso de Ruta'), findsOneWidget);
      final a = container(tester)
          .read(clientRecordsProvider)
          .firstWhere((c) => c.id == 'a');
      expect(a.hasLocation, isFalse);
      await _unmount(tester);
    });

    testWidgets('Confirmar saves the map center as the client location',
        (tester) async {
      await _pumpHome(tester, clients: clients, pickingClientId: 'a');

      await tester.tap(find.text('Confirmar Ubicación'));
      await tester.pump();
      await tester.pump();

      final a = container(tester)
          .read(clientRecordsProvider)
          .firstWhere((c) => c.id == 'a');
      // Nothing moved the map: the center is the default one
      expect(a.latitude, closeTo(-30.729639, 1e-6));
      expect(a.longitude, closeTo(-70.764389, 1e-6));
      expect(container(tester).read(locationPickerClientProvider), isNull);
      expect(find.text('Ubicación de Cliente a guardada.'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('dragging the map changes the confirmed position',
        (tester) async {
      await _pumpHome(tester, clients: clients, pickingClientId: 'a');

      await tester.drag(find.byType(FlutterMap), const Offset(-120, 80));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar Ubicación'));
      await tester.pump();
      await tester.pump();

      final a = container(tester)
          .read(clientRecordsProvider)
          .firstWhere((c) => c.id == 'a');
      // Dragging left moves the center east; dragging down moves it north
      expect(a.longitude!, greaterThan(-70.764389));
      expect(a.latitude!, greaterThan(-30.729639));
      await _unmount(tester);
    });
  });
}
