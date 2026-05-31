import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fakes.dart';
import '../helpers/mocks.dart';
import '../helpers/test_data.dart';
import 'helpers/mock_api_setup.dart';

void main() {
  late MockApiClient mockApi;

  setUpAll(registerFallbacks);

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
      // Create and Join buttons are in the AppBar
      expect(find.text('Create Group'), findsOneWidget);
      expect(find.text('Join Group'), findsOneWidget);
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

      // Tap "Create Group" in AppBar
      await tester.tap(find.text('Create Group'));
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

      // Tap "Join Group" in AppBar
      await tester.tap(find.text('Join Group'));
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
      expect(find.text('Geofences'), findsWidgets);
      // Use ListTile finder to disambiguate "Home" from bottom nav
      expect(find.widgetWithText(ListTile, 'Home'), findsOneWidget);
      expect(find.text('100m radius'), findsOneWidget);
    });
    testWidgets('non-admin member sees leave button, not delete',
        (tester) async {
      setupAuthenticatedStubs(mockApi);
      setupGroupStubs(mockApi, groups: [groupJson]);
      setupGeofenceStubs(mockApi);
      setupLocationStubs(mockApi);

      // Override members to return current user as non-admin
      when(() => mockApi.getMembers(any()))
          .thenAnswer((_) async => fakeResponse({
                'members': [adminOtherMemberJson, nonAdminMemberJson],
              }));

      await pumpAppWithMocks(tester, apiClient: mockApi);

      // Navigate to Groups tab
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();

      // Tap the group
      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      // Should see leave button, not delete
      expect(find.byIcon(Icons.exit_to_app), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsNothing);
    });

    testWidgets('leave group shows confirmation and navigates to list',
        (tester) async {
      setupAuthenticatedStubs(mockApi);
      setupGroupStubs(mockApi, groups: [groupJson]);
      setupGeofenceStubs(mockApi);
      setupLocationStubs(mockApi);

      // Current user is non-admin
      when(() => mockApi.getMembers(any()))
          .thenAnswer((_) async => fakeResponse({
                'members': [adminOtherMemberJson, nonAdminMemberJson],
              }));

      // After leaving, groups list is empty
      var leaveCount = 0;
      when(() => mockApi.removeMember(any(), any())).thenAnswer((_) async {
        leaveCount++;
        return fakeResponse(null, statusCode: 204);
      });

      await pumpAppWithMocks(tester, apiClient: mockApi);

      // Navigate to group detail
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      // Tap leave button
      await tester.tap(find.byIcon(Icons.exit_to_app));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text('Leave Group?'), findsOneWidget);
      expect(
        find.text(
            "You will no longer see this group's members or geofences."),
        findsOneWidget,
      );

      // After confirm, groups list returns empty
      when(() => mockApi.getGroups())
          .thenAnswer((_) async => fakeResponse({'groups': <Map<String, dynamic>>[]}));

      // Confirm leave
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();

      // Should have called removeMember
      expect(leaveCount, 1);

      // Should be back on groups list
      expect(find.text('No groups yet'), findsOneWidget);
    });

    testWidgets('cancel leave group does not leave', (tester) async {
      setupAuthenticatedStubs(mockApi);
      setupGroupStubs(mockApi, groups: [groupJson]);
      setupGeofenceStubs(mockApi);
      setupLocationStubs(mockApi);

      // Current user is non-admin
      when(() => mockApi.getMembers(any()))
          .thenAnswer((_) async => fakeResponse({
                'members': [adminOtherMemberJson, nonAdminMemberJson],
              }));

      await pumpAppWithMocks(tester, apiClient: mockApi);

      // Navigate to group detail
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      // Tap leave button
      await tester.tap(find.byIcon(Icons.exit_to_app));
      await tester.pumpAndSettle();

      // Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Should still be on detail screen
      expect(find.text('Members'), findsOneWidget);

      // removeMember should never have been called
      verifyNever(() => mockApi.removeMember(any(), any()));
    });
  });
}
