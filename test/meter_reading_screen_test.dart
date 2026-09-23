import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aguas_monte_patria/models/client_meter_record.dart';
import 'package:aguas_monte_patria/providers/meter_providers.dart';
import 'package:aguas_monte_patria/screens/meter_reading_screen.dart';
import 'package:aguas_monte_patria/services/meter_repository.dart';

class _FakeClientRecordsNotifier extends ClientRecordsNotifier {
  _FakeClientRecordsNotifier(List<ClientMeterRecord> records)
      : super(MeterRepository()) {
    state = records;
  }
}

Widget _buildScreen(ClientMeterRecord client) {
  return ProviderScope(
    overrides: [
      clientRecordsProvider
          .overrideWith((ref) => _FakeClientRecordsNotifier([client])),
    ],
    child: MaterialApp(home: MeterReadingScreen(clientId: client.id)),
  );
}

void main() {
  final visitedClient = ClientMeterRecord(
    id: 'test-001',
    clientNumber: '12345',
    ownerName: 'Test User',
    readingTwoMonthsAgo: 100,
    readingOneMonthAgo: 120,
    currentReading: 145,
    isVisited: true,
    latitude: -30.7,
    longitude: -70.7,
  );

  testWidgets('pre-fills the existing reading without errors', (tester) async {
    await tester.pumpWidget(_buildScreen(visitedClient));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller!.text, '145');
  });

  testWidgets('clearing the field does not restore the old reading',
      (tester) async {
    await tester.pumpWidget(_buildScreen(visitedClient));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '');
    await tester.pumpAndSettle();

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller!.text, isEmpty);

    await tester.enterText(find.byType(TextFormField), '150');
    await tester.pumpAndSettle();
    expect(find.text('30'), findsOneWidget); // 150 - 120
  });
}
