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

  /// Helper: navigate from map to a geofence detail screen.
  Future<void> navigateToGeofenceDetail(WidgetTester tester) async {
    await tester.tap(find.text('Groups'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
  }

  group('Geofence flow', () {
    testWidgets('navigate from group detail to geofence create screen',
        (tester) async {
      setupAuthenticatedStubs(mockApi);
      setupGroupStubs(mockApi, groups: [groupJson]);
      setupGeofenceStubs(mockApi);
      setupLocationStubs(mockApi);

      await pumpAppWithMocks(tester, apiClient: mockApi);

      // Go to Groups > tap group
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      // Tap "Add Geofence" FAB
      await tester.tap(find.text('Add Geofence'));
      await tester.pumpAndSettle();

      // Should be on geofence create screen
      expect(find.text('Create Geofence'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Name'), findsOneWidget);
      expect(
          find.widgetWithText(TextField, 'Radius (meters)'), findsOneWidget);
    });

    testWidgets('geofence detail shows name, radius, notification toggles',
        (tester) async {
      setupAuthenticatedStubs(mockApi);
      setupGroupStubs(mockApi, groups: [groupJson]);
      setupGeofenceStubs(mockApi, geofences: [geofenceJson]);
      setupLocationStubs(mockApi);

      await pumpAppWithMocks(tester, apiClient: mockApi);
      await navigateToGeofenceDetail(tester);

      // Top of the page should show name and radius
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('100 meters'), findsOneWidget);
      expect(find.text('Our house'), findsOneWidget);

      // Scroll down to reveal notification toggles (below GoogleMap + other tiles)
      await tester.scrollUntilVisible(
        find.text('Notify on Entry'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Notify on Entry'), findsOneWidget);
      expect(find.text('Notify on Exit'), findsOneWidget);
    });

    testWidgets('toggle notification switch calls API', (tester) async {
      setupAuthenticatedStubs(mockApi);
      setupGroupStubs(mockApi, groups: [groupJson]);
      setupGeofenceStubs(mockApi, geofences: [geofenceJson]);
      setupLocationStubs(mockApi);

      await pumpAppWithMocks(tester, apiClient: mockApi);
      await navigateToGeofenceDetail(tester);

      // Scroll down to reveal notification switches
      await tester.scrollUntilVisible(
        find.text('Notify on Exit'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();

      // Toggle "Notify on Exit" (off → on per subscriptionJson)
      await tester.tap(find.widgetWithText(SwitchListTile, 'Notify on Exit'));
      await tester.pumpAndSettle();

      // Verify upsertSubscription was called
      verify(() => mockApi.upsertSubscription(any(), any())).called(1);
    });

    testWidgets('delete geofence shows confirmation, confirms navigates back',
        (tester) async {
      setupAuthenticatedStubs(mockApi);
      setupGroupStubs(mockApi, groups: [groupJson]);
      setupGeofenceStubs(mockApi, geofences: [geofenceJson]);
      setupLocationStubs(mockApi);

      await pumpAppWithMocks(tester, apiClient: mockApi);
      await navigateToGeofenceDetail(tester);

      // Tap delete icon in app bar
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();

      // Confirm dialog
      expect(find.text('Delete Geofence?'), findsOneWidget);
      expect(find.text('This action cannot be undone.'), findsOneWidget);

      // After deletion, geofences list refreshes to empty
      when(() => mockApi.getGeofences(any()))
          .thenAnswer((_) async => fakeResponse({'geofences': []}));

      // Confirm delete
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      // Should navigate back to group detail
      verify(() => mockApi.deleteGeofence(any(), any())).called(1);
      expect(find.text('Members'), findsOneWidget);
      expect(find.text('No geofences yet'), findsOneWidget);
    });
  });
}
