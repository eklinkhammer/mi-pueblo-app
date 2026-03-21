import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';
import '../helpers/test_data.dart';
import 'helpers/mock_api_setup.dart';

void main() {
  late MockApiClient mockApi;

  setUpAll(() {
    registerFallbacks();
    registerGoogleMapsMock();
  });

  setUp(() {
    mockApi = MockApiClient();
  });

  group('Navigation', () {
    testWidgets('tab switching: Map ↔ Groups ↔ Settings via bottom nav',
        (tester) async {
      setupAuthenticatedStubs(mockApi);
      setupGroupStubs(mockApi);
      setupGeofenceStubs(mockApi);
      setupLocationStubs(mockApi);

      await pumpAppWithMocks(tester, apiClient: mockApi);

      // Starts on Map (title in both AppBar and bottom nav)
      expect(find.text('Select a group to view the map'), findsOneWidget);

      // Switch to Groups
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();
      expect(find.text('No groups yet'), findsOneWidget);

      // Switch to Settings
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Sign Out'), findsOneWidget);

      // Back to Map (tap the bottom nav label)
      await tester.tap(find.text('Map').last);
      await tester.pumpAndSettle();
      expect(find.text('Select a group to view the map'), findsOneWidget);
    });

    testWidgets('settings screen shows user profile info', (tester) async {
      setupAuthenticatedStubs(mockApi);
      setupGroupStubs(mockApi);
      setupGeofenceStubs(mockApi);
      setupLocationStubs(mockApi);

      await pumpAppWithMocks(tester, apiClient: mockApi);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('alice@example.com'), findsOneWidget);
      expect(find.text('Location Sharing'), findsOneWidget);
      expect(find.text('Location Permissions'), findsOneWidget);
    });

    testWidgets('map screen shows "Select a group" when no group selected',
        (tester) async {
      setupAuthenticatedStubs(mockApi);
      setupGroupStubs(mockApi);
      setupGeofenceStubs(mockApi);
      setupLocationStubs(mockApi);

      await pumpAppWithMocks(tester, apiClient: mockApi);

      expect(find.text('Select a group to view the map'), findsOneWidget);
    });

    testWidgets('deep navigation: Groups → Group Detail → back',
        (tester) async {
      setupAuthenticatedStubs(mockApi);
      setupGroupStubs(mockApi, groups: [groupJson]);
      setupGeofenceStubs(mockApi);
      setupLocationStubs(mockApi);

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
