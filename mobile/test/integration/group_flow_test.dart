import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fakes.dart';
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

  group('Group flow', () {
    testWidgets('authenticated user sees empty group list', (tester) async {
      setupAuthenticatedStubs(mockApi);
      setupGroupStubs(mockApi); // empty groups by default
      setupGeofenceStubs(mockApi);
      setupLocationStubs(mockApi);

      await pumpAppWithMocks(tester, apiClient: mockApi);

      // Navigate to Groups tab
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();

      expect(find.text('No groups yet'), findsOneWidget);
      expect(find.text('Create a Group'), findsOneWidget);
      expect(find.text('Join with Invite Code'), findsOneWidget);
    });

    testWidgets('create group navigates to group detail', (tester) async {
      setupAuthenticatedStubs(mockApi);
      setupGroupStubs(mockApi);
      setupGeofenceStubs(mockApi);
      setupLocationStubs(mockApi);

      await pumpAppWithMocks(tester, apiClient: mockApi);

      // Navigate to Groups tab
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();

      // Tap "Create a Group"
      await tester.tap(find.text('Create a Group'));
      await tester.pumpAndSettle();

      // Should be on create group screen
      expect(find.text('Create Group'), findsWidgets);

      // Enter group name
      await tester.enterText(
          find.widgetWithText(TextField, 'Group Name'), 'Family');

      // After create, the groups list will be refreshed; stub it to contain the new group
      when(() => mockApi.getGroups()).thenAnswer(
          (_) async => fakeResponse({'groups': [groupJson]}));

      // Tap create
      await tester.tap(find.widgetWithText(FilledButton, 'Create Group'));
      await tester.pumpAndSettle();

      // Should navigate to group detail, showing Members section
      expect(find.text('Members'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('group list shows created groups', (tester) async {
      setupAuthenticatedStubs(mockApi);
      setupGroupStubs(mockApi, groups: [groupJson]);
      setupGeofenceStubs(mockApi);
      setupLocationStubs(mockApi);

      await pumpAppWithMocks(tester, apiClient: mockApi);

      // Navigate to Groups tab
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();

      // Should show the group in the list
      expect(find.text('Family'), findsOneWidget);
    });

    testWidgets('join group via invite code navigates to group detail',
        (tester) async {
      setupAuthenticatedStubs(mockApi);
      setupGroupStubs(mockApi);
      setupGeofenceStubs(mockApi);
      setupLocationStubs(mockApi);

      await pumpAppWithMocks(tester, apiClient: mockApi);

      // Navigate to Groups tab
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();

      // Tap "Join with Invite Code"
      await tester.tap(find.text('Join with Invite Code'));
      await tester.pumpAndSettle();

      expect(find.text('Join Group'), findsWidgets);

      // Enter invite code
      await tester.enterText(
          find.widgetWithText(TextField, 'Invite Code'), 'ABC123');

      // After join, the groups list will be refreshed
      when(() => mockApi.getGroups()).thenAnswer(
          (_) async => fakeResponse({'groups': [groupJson]}));

      // Tap join
      await tester.tap(find.widgetWithText(FilledButton, 'Join Group'));
      await tester.pumpAndSettle();

      // Should navigate to group detail
      expect(find.text('Members'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('group detail shows members and geofences sections',
        (tester) async {
      setupAuthenticatedStubs(mockApi);
      setupGroupStubs(mockApi, groups: [groupJson]);
      setupGeofenceStubs(mockApi, geofences: [geofenceJson]);
      setupLocationStubs(mockApi);

      await pumpAppWithMocks(tester, apiClient: mockApi);

      // Navigate to Groups tab
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();

      // Tap the group
      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      // Should show both sections
      expect(find.text('Members'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Geofences'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('100m radius'), findsOneWidget);
    });
  });
}
