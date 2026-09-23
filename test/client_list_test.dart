import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aguas_monte_patria/models/client_meter_record.dart';
import 'package:aguas_monte_patria/providers/client_list_providers.dart';
import 'package:aguas_monte_patria/providers/meter_providers.dart';
import 'package:aguas_monte_patria/screens/client_list_screen.dart';
import 'package:aguas_monte_patria/screens/meter_reading_screen.dart';
import 'package:aguas_monte_patria/services/meter_repository.dart';

class _FakeClientRecordsNotifier extends ClientRecordsNotifier {
  _FakeClientRecordsNotifier(List<ClientMeterRecord> records)
      : super(MeterRepository()) {
    state = records;
  }
}

ClientMeterRecord _client(
  String id,
  String number,
  String name, {
  int? reading,
  String? reason,
}) {
  return ClientMeterRecord(
    id: id,
    clientNumber: number,
    ownerName: name,
    readingTwoMonthsAgo: 100,
    readingOneMonthAgo: 120,
    currentReading: reading,
    isVisited: reading != null || reason != null,
    latitude: -30.7,
    longitude: -70.7,
    nonReadingReason: reason,
  );
}

final _clients = [
  _client('1', '40225001', 'José Luis Araya Muñoz'),
  _client('2', '40225002', 'Catalina Fernández', reading: 140),
  _client('3', '40225003', 'Pedro Tapia', reason: 'Perro'),
  _client('4', '40225004', 'Andrés Contreras', reading: 130),
];

ProviderContainer _container() {
  final container = ProviderContainer(overrides: [
    clientRecordsProvider
        .overrideWith((ref) => _FakeClientRecordsNotifier(_clients)),
  ]);
  addTearDown(container.dispose);
  // Keep the autoDispose providers alive for the whole test.
  container.listen(filteredClientsProvider, (_, _) {});
  return container;
}

List<String> _names(ProviderContainer c) =>
    c.read(filteredClientsProvider).map((r) => r.ownerName).toList();

void main() {
  group('filteredClientsProvider', () {
    test('returns every client sorted by name', () {
      expect(_names(_container()), [
        'Andrés Contreras',
        'Catalina Fernández',
        'José Luis Araya Muñoz',
        'Pedro Tapia',
      ]);
    });

    test('searches by name ignoring case and accents', () {
      final c = _container();
      c.read(clientSearchQueryProvider.notifier).state = 'MUNOZ';
      expect(_names(c), ['José Luis Araya Muñoz']);
    });

    test('searches by client number', () {
      final c = _container();
      c.read(clientSearchQueryProvider.notifier).state = '003';
      expect(_names(c), ['Pedro Tapia']);
    });

    test('filters by status and combines with search', () {
      final c = _container();
      c.read(clientFilterStatusProvider.notifier).state = VisitStatus.read;
      expect(_names(c), ['Andrés Contreras', 'Catalina Fernández']);

      c.read(clientSearchQueryProvider.notifier).state = 'cata';
      expect(_names(c), ['Catalina Fernández']);

      c.read(clientFilterStatusProvider.notifier).state =
          VisitStatus.noReading;
      expect(_names(c), isEmpty);
    });
  });

  test('routeProgressProvider splits visited into read and no reading', () {
    final progress = _container().read(routeProgressProvider);
    expect(progress.total, 4);
    expect(progress.visited, 3);
    expect(progress.read, 2);
    expect(progress.noReading, 1);
    expect(progress.percent, 75);
  });

  group('ClientListScreen', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          clientRecordsProvider
              .overrideWith((ref) => _FakeClientRecordsNotifier(_clients)),
        ],
        child: const MaterialApp(home: ClientListScreen()),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('shows clients with status details and counts',
        (tester) async {
      await pumpScreen(tester);

      expect(find.text('Todos (4)'), findsOneWidget);
      expect(find.text('Pendiente (1)'), findsOneWidget);
      expect(find.text('Leído (2)'), findsOneWidget);
      expect(find.text('Sin lectura (1)'), findsOneWidget);
      expect(find.text('N° 40225003 • Sin lectura: Perro'), findsOneWidget);
      expect(find.text('N° 40225002 • Lectura: 140 m³'), findsOneWidget);
    });

    testWidgets('search and filter chips narrow the list', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Sin lectura (1)'));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsOneWidget);
      expect(find.text('Pedro Tapia'), findsOneWidget);

      await tester.tap(find.text('Todos (4)'));
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNothing);
      expect(find.text('No hay clientes que coincidan'), findsOneWidget);
    });

    testWidgets('tapping a client opens the reading screen', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Pedro Tapia'));
      await tester.pumpAndSettle();

      final screen =
          tester.widget<MeterReadingScreen>(find.byType(MeterReadingScreen));
      expect(screen.clientId, '3');
    });
  });
}
