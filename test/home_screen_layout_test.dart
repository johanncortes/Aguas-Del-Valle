import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:aguas_monte_patria/models/client_meter_record.dart';
import 'package:aguas_monte_patria/providers/meter_providers.dart';
import 'package:aguas_monte_patria/screens/client_list_screen.dart';
import 'package:aguas_monte_patria/screens/home_screen.dart';
import 'package:aguas_monte_patria/services/cached_tile_provider.dart';
import 'package:aguas_monte_patria/services/meter_repository.dart';

/// Points the tile cache at a temp directory instead of the real one.
class _FakePathProvider extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      Directory.systemTemp.path;
}

class _FakeClientRecordsNotifier extends ClientRecordsNotifier {
  _FakeClientRecordsNotifier() : super(MeterRepository()) {
    ClientMeterRecord client(String id, {int? reading, String? reason}) =>
        ClientMeterRecord(
          id: id,
          clientNumber: id,
          ownerName: 'Cliente $id',
          readingTwoMonthsAgo: 0,
          readingOneMonthAgo: 0,
          currentReading: reading,
          isVisited: reading != null || reason != null,
          latitude: -30.73,
          longitude: -70.76,
          nonReadingReason: reason,
        );
    state = [
      client('1'),
      client('2', reading: 5),
      client('3', reason: 'Perro'),
    ];
  }

  @override
  Future<void> loadClients() async {}
}

Future<void> _pumpHome(WidgetTester tester, double width) async {
  // The test font renders every glyph as a full square, so text is wider
  // than on a device: passing here leaves margin for large text settings.
  tester.view.physicalSize = Size(width * 3, 800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // The cache's init does real file I/O, which never completes inside the
  // test's fake-async zone; run it for real first so tiles don't wait on it.
  await tester.runAsync(CachedTileProvider.initialize);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      clientRecordsProvider.overrideWith((ref) => _FakeClientRecordsNotifier()),
    ],
    child: const MaterialApp(home: HomeScreen()),
  ));
  await tester.pump(const Duration(milliseconds: 100));
}

/// Removes the map and lets pending tile loads settle before the test ends.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() => PathProviderPlatform.instance = _FakePathProvider());

  testWidgets('header and bottom panel fit on a 320 dp screen',
      (tester) async {
    await _pumpHome(tester, 320);

    expect(tester.takeException(), isNull);
    expect(find.text('Pendientes'), findsOneWidget);
    expect(find.text('Leídos'), findsOneWidget);
    expect(find.text('Sin lectura'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets('list button opens the client list', (tester) async {
    await _pumpHome(tester, 360);

    await tester.tap(find.byTooltip('Lista de clientes'));
    await tester.pumpAndSettle();
    expect(find.byType(ClientListScreen), findsOneWidget);

    await _unmount(tester);
  });
}
