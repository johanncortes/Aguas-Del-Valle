import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:aguas_monte_patria/models/client_meter_record.dart';
import 'package:aguas_monte_patria/providers/meter_providers.dart';
import 'package:aguas_monte_patria/screens/add_client_modal.dart';
import 'package:aguas_monte_patria/services/meter_repository.dart';

class _FakeClientRecordsNotifier extends ClientRecordsNotifier {
  _FakeClientRecordsNotifier(List<ClientMeterRecord> records)
      : super(MeterRepository()) {
    state = records;
  }

  final created = <({String clientNumber, int twoMonths, int oneMonth})>[];

  @override
  Future<ClientMeterRecord> addClient({
    required String ownerName,
    required String clientNumber,
    required double latitude,
    required double longitude,
    int readingTwoMonthsAgo = 0,
    int readingOneMonthAgo = 0,
    int? currentReading,
  }) async {
    created.add((
      clientNumber: clientNumber,
      twoMonths: readingTwoMonthsAgo,
      oneMonth: readingOneMonthAgo,
    ));
    return ClientMeterRecord(
      id: 'dyn-test',
      clientNumber: clientNumber,
      ownerName: ownerName,
      readingTwoMonthsAgo: readingTwoMonthsAgo,
      readingOneMonthAgo: readingOneMonthAgo,
      latitude: latitude,
      longitude: longitude,
    );
  }
}

final _existing = ClientMeterRecord(
  id: 'sp-001',
  clientNumber: '40225001',
  ownerName: 'Cliente Existente',
  readingTwoMonthsAgo: 100,
  readingOneMonthAgo: 120,
  latitude: -30.7,
  longitude: -70.7,
);

/// Opens the modal from a home route so saving can pop back.
Future<_FakeClientRecordsNotifier> _openModal(WidgetTester tester) async {
  final notifier = _FakeClientRecordsNotifier([_existing]);
  await tester.pumpWidget(ProviderScope(
    overrides: [clientRecordsProvider.overrideWith((ref) => notifier)],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showModalBottomSheet<bool>(
              context: context,
              isScrollControlled: true,
              builder: (_) =>
                  const AddClientModal(location: LatLng(-30.72, -70.76)),
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

Future<void> _fill(
  WidgetTester tester, {
  required String number,
  String twoMonths = '0',
  String oneMonth = '0',
}) async {
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Ej: Juan Pérez Soto'), 'Nuevo');
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Ej: 40225011'), number);
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Hace 2 meses'), twoMonths);
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Hace 1 mes'), oneMonth);
}

Future<void> _tapCreate(WidgetTester tester) async {
  final create = find.text('Crear Cliente');
  await tester.ensureVisible(create);
  await tester.tap(create);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('rejects a client number that already exists', (tester) async {
    final notifier = await _openModal(tester);

    await _fill(tester, number: ' 40225001 ');
    await _tapCreate(tester);

    expect(find.text('Ya existe un cliente con este N°'), findsOneWidget);
    expect(notifier.created, isEmpty);
  });

  testWidgets('rejects a 1-month reading lower than the 2-month one',
      (tester) async {
    final notifier = await _openModal(tester);

    await _fill(tester, number: '40225099', twoMonths: '150', oneMonth: '140');
    await _tapCreate(tester);

    expect(find.text('No puede ser menor que la de hace 2 meses'),
        findsOneWidget);
    expect(notifier.created, isEmpty);
  });

  testWidgets('creates a client with a new number and valid history',
      (tester) async {
    final notifier = await _openModal(tester);

    await _fill(tester, number: '40225099', twoMonths: '150', oneMonth: '150');
    await _tapCreate(tester);

    expect(notifier.created.single.clientNumber, '40225099');
    expect(notifier.created.single.twoMonths, 150);
    expect(notifier.created.single.oneMonth, 150);
    expect(find.byType(AddClientModal), findsNothing);
  });
}
