import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aguas_monte_patria/models/client_meter_record.dart';
import 'package:aguas_monte_patria/providers/client_list_providers.dart';
import 'package:aguas_monte_patria/providers/meter_providers.dart';
import 'package:aguas_monte_patria/screens/edit_client_modal.dart';
import 'package:aguas_monte_patria/screens/meter_reading_screen.dart';
import 'package:aguas_monte_patria/services/meter_repository.dart';
import 'package:aguas_monte_patria/services/photo_service.dart';

typedef _SaveCall = ({
  int? reading,
  String? nonReadingReason,
  String? observations,
  String? photoPath,
});

class _FakeClientRecordsNotifier extends ClientRecordsNotifier {
  _FakeClientRecordsNotifier(List<ClientMeterRecord> records)
      : super(MeterRepository()) {
    state = records;
  }

  final saves = <_SaveCall>[];

  /// What saveReading returns (the saved record in the real notifier).
  ClientMeterRecord? savedRecord;

  ClientMeterRecord _update(String id,
          ClientMeterRecord Function(ClientMeterRecord) change) =>
      change(state.firstWhere((c) => c.id == id));

  @override
  Future<void> updateClientData(
    String clientId, {
    required String ownerName,
    required String? sector,
    required int readingOneMonthAgo,
    required int readingTwoMonthsAgo,
  }) async {
    final updated = _update(
        clientId,
        (c) => c.withMasterData(
              ownerName: ownerName.trim(),
              sector: sector,
              readingOneMonthAgo: readingOneMonthAgo,
              readingTwoMonthsAgo: readingTwoMonthsAgo,
              latitude: c.latitude,
              longitude: c.longitude,
            ));
    state = [for (final c in state) c.id == clientId ? updated : c];
  }

  @override
  Future<void> clearClientLocation(String clientId) async {
    final updated = _update(
        clientId,
        (c) => c.withMasterData(
              ownerName: c.ownerName,
              sector: c.sector,
              readingOneMonthAgo: c.readingOneMonthAgo,
              readingTwoMonthsAgo: c.readingTwoMonthsAgo,
              latitude: null,
              longitude: null,
            ));
    state = [for (final c in state) c.id == clientId ? updated : c];
  }

  @override
  Future<ClientMeterRecord?> saveReading(
    String clientId, {
    int? reading,
    String? nonReadingReason,
    String? observations,
    String? photoPath,
  }) async {
    saves.add((
      reading: reading,
      nonReadingReason: nonReadingReason,
      observations: observations,
      photoPath: photoPath,
    ));
    return savedRecord;
  }
}

class _FakePhotoService extends PhotoService {
  /// Paths returned by successive takePhoto calls; null = cancelled.
  final photos = <String?>[];
  bool fail = false;
  final deleted = <String>[];

  @override
  Future<String?> takePhoto(String clientId) async {
    if (fail) throw Exception('camera_access_denied');
    return photos.removeAt(0);
  }

  @override
  Future<void> deletePhoto(String path) async => deleted.add(path);
}

/// Pushes the screen on top of a home route so saving can pop back.
Future<_FakeClientRecordsNotifier> _openScreen(
  WidgetTester tester,
  ClientMeterRecord client, {
  _FakePhotoService? photos,
}) async {
  final notifier = _FakeClientRecordsNotifier([client]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      clientRecordsProvider.overrideWith((ref) => notifier),
      photoServiceProvider.overrideWithValue(photos ?? _FakePhotoService()),
    ],
    child: MaterialApp(
      // Scaffold so the post-save SnackBar can show after popping back
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MeterReadingScreen(clientId: client.id),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return notifier;
}

Future<void> _tapSave(WidgetTester tester) async {
  final save = find.text('Guardar Información');
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

Finder get _readingField => find.byWidgetPredicate(
    (w) => w is TextFormField && w.key != const Key('observationsField'));

void main() {
  // Previous consumption: 120 - 100 = 20 m³
  ClientMeterRecord client({
    int? currentReading,
    String? reason,
    String? photoPath,
    bool located = true,
  }) =>
      ClientMeterRecord(
        id: 'test-001',
        clientNumber: '12345',
        ownerName: 'Test User',
        readingTwoMonthsAgo: 100,
        readingOneMonthAgo: 120,
        currentReading: currentReading,
        isVisited: currentReading != null || reason != null,
        latitude: located ? -30.7 : null,
        longitude: located ? -70.7 : null,
        nonReadingReason: reason,
        photoPath: photoPath,
      );

  testWidgets('pre-fills the existing reading without errors', (tester) async {
    await _openScreen(tester, client(currentReading: 145));

    expect(tester.takeException(), isNull);
    final field = tester.widget<TextFormField>(_readingField);
    expect(field.controller!.text, '145');
  });

  testWidgets('clearing the field does not restore the old reading',
      (tester) async {
    await _openScreen(tester, client(currentReading: 145));

    await tester.enterText(_readingField, '');
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(_readingField).controller!.text,
        isEmpty);

    await tester.enterText(_readingField, '150');
    await tester.pumpAndSettle();
    expect(find.text('30'), findsOneWidget); // 150 - 120
  });

  testWidgets('normal reading saves without a dialog', (tester) async {
    final notifier = await _openScreen(tester, client());

    await tester.enterText(_readingField, '140'); // consumption 20
    await _tapSave(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(notifier.saves.single.reading, 140);
    expect(notifier.saves.single.nonReadingReason, isNull);
  });

  testWidgets('negative consumption asks for confirmation', (tester) async {
    final notifier = await _openScreen(tester, client());

    await tester.enterText(_readingField, '110');
    await _tapSave(tester);
    expect(find.text('Consumo negativo'), findsOneWidget);

    await tester.tap(find.text('Corregir'));
    await tester.pumpAndSettle();
    expect(notifier.saves, isEmpty);

    await _tapSave(tester);
    await tester.tap(find.text('Guardar de todos modos'));
    await tester.pumpAndSettle();
    expect(notifier.saves.single.reading, 110);
  });

  testWidgets('consumption over 3x the previous month warns', (tester) async {
    final notifier = await _openScreen(tester, client());

    await tester.enterText(_readingField, '181'); // 61 > 3 * 20
    await _tapSave(tester);
    expect(find.text('Consumo anormal'), findsOneWidget);

    await tester.tap(find.text('Corregir'));
    await tester.pumpAndSettle();
    expect(notifier.saves, isEmpty);

    await tester.enterText(_readingField, '180'); // 60 == 3 * 20, allowed
    await _tapSave(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(notifier.saves.single.reading, 180);
  });

  testWidgets('choosing a reason hides the reading and saves the reason',
      (tester) async {
    final notifier = await _openScreen(tester, client(currentReading: 145));

    await tester.tap(find.byKey(const Key('nonReadingReasonDropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No se pudo leer: Perro').last);
    await tester.pumpAndSettle();

    expect(_readingField, findsNothing);

    await tester.enterText(
        find.byKey(const Key('observationsField')), 'Perro suelto');
    await _tapSave(tester);

    expect(notifier.saves.single.reading, isNull);
    expect(notifier.saves.single.nonReadingReason, 'Perro');
    expect(notifier.saves.single.observations, 'Perro suelto');
  });

  testWidgets('"Otro" requires observations', (tester) async {
    final notifier = await _openScreen(tester, client());

    await tester.tap(find.byKey(const Key('nonReadingReasonDropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No se pudo leer: Otro').last);
    await tester.pumpAndSettle();

    await _tapSave(tester);
    expect(find.text('Describa el motivo en observaciones'), findsOneWidget);
    expect(notifier.saves, isEmpty);
  });

  testWidgets('pre-selects a saved reason', (tester) async {
    await _openScreen(tester, client(reason: 'Casa cerrada'));

    expect(find.text('No se pudo leer: Casa cerrada'), findsOneWidget);
    expect(_readingField, findsNothing);
  });

  testWidgets('tells the reader when the visit was saved without GPS',
      (tester) async {
    final notifier = await _openScreen(tester, client());
    notifier.savedRecord = client(currentReading: 140); // no coordinates

    await tester.enterText(_readingField, '140');
    await _tapSave(tester);

    expect(find.textContaining('(sin ubicación GPS)'), findsOneWidget);
  });

  testWidgets('no GPS notice when the position was captured', (tester) async {
    final notifier = await _openScreen(tester, client());
    notifier.savedRecord = client(currentReading: 140)
        .copyWith(readingLatitude: -30.7, readingLongitude: -70.7);

    await tester.enterText(_readingField, '140');
    await _tapSave(tester);

    expect(find.textContaining('Lectura guardada'), findsOneWidget);
    expect(find.textContaining('(sin ubicación GPS)'), findsNothing);
  });

  group('evidence photo', () {
    final thumbnail = find.byKey(const Key('evidencePhotoThumbnail'));

    Future<void> tapCamera(WidgetTester tester, String label) async {
      final button = find.text(label);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets('takes a photo, shows it and saves its path', (tester) async {
      final photos = _FakePhotoService()..photos.add('/p/one.jpg');
      final notifier =
          await _openScreen(tester, client(), photos: photos);
      expect(thumbnail, findsNothing);

      await tapCamera(tester, 'Tomar foto de evidencia (Opcional)');
      expect(thumbnail, findsOneWidget);
      expect(find.text('Volver a tomar foto'), findsOneWidget);

      await tester.enterText(_readingField, '140');
      await _tapSave(tester);
      expect(notifier.saves.single.photoPath, '/p/one.jpg');
      expect(photos.deleted, isEmpty); // the saved photo is kept
    });

    testWidgets('the X removes the photo before saving', (tester) async {
      final photos = _FakePhotoService()..photos.add('/p/one.jpg');
      final notifier =
          await _openScreen(tester, client(), photos: photos);

      await tapCamera(tester, 'Tomar foto de evidencia (Opcional)');
      await tester.tap(find.byTooltip('Eliminar foto'));
      await tester.pumpAndSettle();
      expect(thumbnail, findsNothing);

      await tester.enterText(_readingField, '140');
      await _tapSave(tester);
      expect(notifier.saves.single.photoPath, isNull);
      expect(photos.deleted, ['/p/one.jpg']); // discarded file cleaned up
    });

    testWidgets('a saved photo is shown when editing and deleted once '
        'replaced', (tester) async {
      final photos = _FakePhotoService()..photos.add('/p/new.jpg');
      final notifier = await _openScreen(
        tester,
        client(currentReading: 140, photoPath: '/p/old.jpg'),
        photos: photos,
      );
      expect(thumbnail, findsOneWidget);

      await tapCamera(tester, 'Volver a tomar foto');
      await _tapSave(tester);

      expect(notifier.saves.single.photoPath, '/p/new.jpg');
      expect(photos.deleted, ['/p/old.jpg']);
    });

    testWidgets('photos taken without saving are deleted on exit',
        (tester) async {
      final photos = _FakePhotoService()..photos.add('/p/one.jpg');
      await _openScreen(tester, client(photoPath: '/p/old.jpg'),
          photos: photos);

      await tapCamera(tester, 'Volver a tomar foto');
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();

      // The new photo is discarded; the previously saved one is kept
      expect(photos.deleted, ['/p/one.jpg']);
    });

    testWidgets('a camera error is reported and saving still works',
        (tester) async {
      final photos = _FakePhotoService()..fail = true;
      final notifier =
          await _openScreen(tester, client(), photos: photos);

      await tapCamera(tester, 'Tomar foto de evidencia (Opcional)');
      expect(find.textContaining('No se pudo abrir la cámara'),
          findsOneWidget);
      await tester.pump(const Duration(seconds: 5)); // SnackBar goes away
      await tester.pumpAndSettle();

      await tester.enterText(_readingField, '140');
      await _tapSave(tester);
      expect(notifier.saves.single.reading, 140);
    });
  });

  group('manual location', () {
    final card = find.byKey(const Key('fixLocationCard'));

    testWidgets('not shown for a client that has a location',
        (tester) async {
      await _openScreen(tester, client());
      expect(card, findsNothing);
    });

    testWidgets('sends the reader to the map in picker mode',
        (tester) async {
      await _openScreen(tester, client(located: false));
      expect(card, findsOneWidget);

      final button = find.text('Ubicar manualmente en el mapa');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      // Back on the first (home) route, with the picker armed for the client
      expect(find.byType(MeterReadingScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
      final container =
          ProviderScope.containerOf(tester.element(find.text('open')));
      expect(container.read(locationPickerClientProvider), 'test-001');
    });
  });

  group('edit client', () {
    Future<void> openEditor(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Editar cliente'));
      await tester.pumpAndSettle();
    }

    Finder field(String label) => find.widgetWithText(TextFormField, label);

    testWidgets('pencil opens the editor with the client number read-only',
        (tester) async {
      await _openScreen(tester, client());
      await openEditor(tester);

      expect(find.byType(EditClientModal), findsOneWidget);
      expect(find.byKey(const Key('editClientNumber')), findsOneWidget);
      expect(find.text('N° 12345'), findsOneWidget);
      // Only name, sector and the two history readings are editable
      expect(
          find.descendant(
              of: find.byType(EditClientModal),
              matching: find.byType(TextFormField)),
          findsNWidgets(4));
    });

    testWidgets('saves name, sector and history', (tester) async {
      final notifier = await _openScreen(tester, client(currentReading: 145));
      await openEditor(tester);

      await tester.enterText(field('Nombre Propietario'), 'Nombre Nuevo');
      await tester.enterText(field('Sector'), 'Varillar');
      await tester.enterText(field('Hace 2 meses'), '105');
      await tester.enterText(field('Hace 1 mes'), '125');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.byType(EditClientModal), findsNothing);
      final c = notifier.state.single;
      expect(c.ownerName, 'Nombre Nuevo');
      expect(c.sector, 'Varillar');
      expect(c.readingTwoMonthsAgo, 105);
      expect(c.readingOneMonthAgo, 125);
      expect(c.currentReading, 145); // cycle untouched
      expect(find.text('Datos del cliente actualizados.'), findsOneWidget);
    });

    testWidgets('rejects a 1-month reading lower than the 2-month one',
        (tester) async {
      final notifier = await _openScreen(tester, client());
      await openEditor(tester);

      await tester.enterText(field('Hace 2 meses'), '150');
      await tester.enterText(field('Hace 1 mes'), '140');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('No puede ser menor que la de hace 2 meses'),
          findsOneWidget);
      expect(notifier.state.single.readingOneMonthAgo, 120);
    });

    testWidgets('clear location is offered only when there is one',
        (tester) async {
      await _openScreen(tester, client(located: false));
      await openEditor(tester);
      expect(find.text('Borrar ubicación del mapa'), findsNothing);
    });

    testWidgets('clears the location after confirming', (tester) async {
      final notifier = await _openScreen(tester, client());
      await openEditor(tester);

      await tester.tap(find.text('Borrar ubicación del mapa'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Borrar ubicación'));
      await tester.pumpAndSettle();

      expect(find.byType(EditClientModal), findsNothing);
      expect(notifier.state.single.hasLocation, isFalse);
      expect(find.text('Ubicación borrada del mapa.'), findsOneWidget);
    });
  });
}
