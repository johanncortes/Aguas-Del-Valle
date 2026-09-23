import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aguas_monte_patria/models/client_meter_record.dart';
import 'package:aguas_monte_patria/providers/meter_providers.dart';
import 'package:aguas_monte_patria/screens/meter_reading_screen.dart';
import 'package:aguas_monte_patria/services/meter_repository.dart';

typedef _SaveCall = ({
  int? reading,
  String? nonReadingReason,
  String? observations,
});

class _FakeClientRecordsNotifier extends ClientRecordsNotifier {
  _FakeClientRecordsNotifier(List<ClientMeterRecord> records)
      : super(MeterRepository()) {
    state = records;
  }

  final saves = <_SaveCall>[];

  @override
  Future<void> saveReading(
    String clientId, {
    int? reading,
    String? nonReadingReason,
    String? observations,
  }) async {
    saves.add((
      reading: reading,
      nonReadingReason: nonReadingReason,
      observations: observations,
    ));
  }
}

/// Pushes the screen on top of a home route so saving can pop back.
Future<_FakeClientRecordsNotifier> _openScreen(
    WidgetTester tester, ClientMeterRecord client) async {
  final notifier = _FakeClientRecordsNotifier([client]);
  await tester.pumpWidget(ProviderScope(
    overrides: [clientRecordsProvider.overrideWith((ref) => notifier)],
    child: MaterialApp(
      home: Builder(
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
  ClientMeterRecord client({int? currentReading, String? reason}) =>
      ClientMeterRecord(
        id: 'test-001',
        clientNumber: '12345',
        ownerName: 'Test User',
        readingTwoMonthsAgo: 100,
        readingOneMonthAgo: 120,
        currentReading: currentReading,
        isVisited: currentReading != null || reason != null,
        latitude: -30.7,
        longitude: -70.7,
        nonReadingReason: reason,
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
}
