import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mocks.dart';
import '../helpers/test_data.dart';
import 'helpers/mock_api_setup.dart';

void main() {
  late MockApiClient mockApi;

  setUpAll(registerFallbacks);

  setUp(() {
    mockApi = MockApiClient();
  });

  group('Navigation', () {
    testWidgets('tab switching: Map ↔ Groups via bottom nav',
        (tester) async {
      setupAuthenticatedStubs(mockApi);
      setupGroupStubs(mockApi);
      setupGeofenceStubs(mockApi);
      setupLocationStubs(mockApi);
      setupStatsStubs(mockApi);

      await pumpAppWithMocks(tester, apiClient: mockApi);

      // Starts on Map with join CTA (no groups)
      expect(find.text('Join My Village'), findsOneWidget);

      // Switch to Groups
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();
      expect(find.text('No groups yet'), findsOneWidget);

      // Back to Map (tap the bottom nav label)
      await tester.tap(find.text('Map').last);
      await tester.pumpAndSettle();
      expect(find.text('Join My Village'), findsOneWidget);
    });

    testWidgets('map screen shows join CTA when no groups',
        (tester) async {
      setupAuthenticatedStubs(mockApi);
      setupGroupStubs(mockApi);
      setupGeofenceStubs(mockApi);
      setupLocationStubs(mockApi);
      setupStatsStubs(mockApi);

      await pumpAppWithMocks(tester, apiClient: mockApi);

      expect(find.text('Join My Village'), findsOneWidget);
    });

    testWidgets('map screen shows group selector when groups exist',
        (tester) async {
      setupAuthenticatedStubs(mockApi);
      setupGroupStubs(mockApi, groups: [groupJson]);
      setupGeofenceStubs(mockApi);
      setupLocationStubs(mockApi);
      setupStatsStubs(mockApi);

      await pumpAppWithMocks(tester, apiClient: mockApi);

      // Group dropdown should show the group name
      expect(find.text('Family'), findsOneWidget);
    });

    testWidgets('deep navigation: Groups → Group Detail → back',
        (tester) async {
      setupAuthenticatedStubs(mockApi);
      setupGroupStubs(mockApi, groups: [groupJson]);
      setupGeofenceStubs(mockApi);
      setupLocationStubs(mockApi);
      setupStatsStubs(mockApi);

      await pumpAppWithMocks(tester, apiClient: mockApi);

      // Go to Groups
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();

      // Tap into group detail
      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      expect(find.text('Members'), findsOneWidget);

      // Press back button in app bar
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Should be back on group list
      expect(find.text('Family'), findsOneWidget);
    });
  });
}
