import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fence/models/app_location.dart';
import 'package:fence/services/location_service.dart';

import 'helpers/test_helpers.dart';

class _MockLocationService extends Mock implements LocationService {}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late LocationService mockLocation;

  setUp(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // Clear auth tokens from prior tests
    const storage = FlutterSecureStorage();
    await storage.deleteAll();

    mockLocation = _MockLocationService();
    when(() => mockLocation.requestPermissions())
        .thenAnswer((_) async => AppPermissionStatus.granted);
    when(() => mockLocation.getCurrentPosition())
        .thenAnswer((_) async => null);
    when(() => mockLocation.startTracking()).thenAnswer((_) async {});
    when(() => mockLocation.stopTracking()).thenAnswer((_) async {});
    when(() => mockLocation.onLocation)
        .thenAnswer((_) => const Stream<AppLocation>.empty());
    when(mockLocation.dispose).thenReturn(null);
  });

  group('Onboarding Flow', () {
    testWidgets('Onboarding screens navigate correctly and complete',
        (tester) async {
      await pumpApp(tester, overrides: [
        locationServiceProvider.overrideWithValue(mockLocation),
      ]);

      // Should be on onboarding screen
      expect(find.text('Mi Pueblo'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);

      // Wait for animations (2s map delay + 1s people delay + 3s animation)
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();

      // Tap Get Started -> permissions screen
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      // Verify permissions screen content
      expect(find.text('What we use'), findsOneWidget);
      expect(find.text('You remain in control'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      // Tap Continue -> completes onboarding, router redirects to map
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Should have left onboarding and landed on map (anonymous view)
      expect(find.text('Get Started'), findsNothing);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('Join Group'), findsOneWidget);
    });

    testWidgets('Full flow — onboarding through anonymous create to map',
        (tester) async {
      await pumpApp(tester, overrides: [
        locationServiceProvider.overrideWithValue(mockLocation),
      ]);

      // Complete onboarding
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // On anonymous map view — tap "Join Group" to open the join sheet
      await tester.tap(find.text('Join Group'));
      await tester.pumpAndSettle();

      // In the join sheet, tap "Create a Group" to navigate to /auth/create
      await tester.tap(find.text('Create a Group'));
      await tester.pumpAndSettle();

      // On anonymous create screen — fill in fields
      await tester.enterText(
        find.widgetWithText(TextField, 'Group Name'),
        'Test Family',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Your Name'),
        'Test User',
      );

      // Tap Create Group (calls backend anonymousCreate endpoint)
      await tester.tap(find.text('Create Group'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // After auth, router recreates and lands on /map (authenticated view)
      expect(find.text('Create Group'), findsNothing);
      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets('Completed onboarding skips onboarding on restart',
        (tester) async {
      // Complete onboarding through UI
      await pumpApp(tester, overrides: [
        locationServiceProvider.overrideWithValue(mockLocation),
      ]);

      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Should be on map (anonymous view), not onboarding
      expect(find.text('Get Started'), findsNothing);
      expect(find.byType(FlutterMap), findsOneWidget);

      // Simulate restart by pumping a fresh app
      // SharedPreferences retains onboarding_completed = true
      await pumpApp(tester, overrides: [
        locationServiceProvider.overrideWithValue(mockLocation),
      ]);

      // Should NOT be on onboarding — it was persisted as completed
      expect(find.text('Get Started'), findsNothing);
    });
  });
}
