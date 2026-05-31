import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fence/models/app_location.dart';
import 'package:fence/services/location_service.dart';

import 'helpers/backend_client.dart';
import 'helpers/test_helpers.dart';

class _MockLocationService extends Mock implements LocationService {}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final backend = BackendTestClient();

  late LocationService mockLocation;

  setUp(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
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

  /// Complete onboarding and navigate to login screen.
  Future<void> completeOnboardingAndGoToLogin(WidgetTester tester) async {
    await pumpApp(tester, overrides: [
      locationServiceProvider.overrideWithValue(mockLocation),
    ]);

    // Complete onboarding screens
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Now on /map (anonymous) — navigate to login
    await tester.tap(find.text('Join Group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create a Group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Already have an account? Sign in'));
    await tester.pumpAndSettle();
  }

  group('Location and Geofence', () {
    testWidgets('Create geofence through UI', (tester) async {
      // Pre-create user and group via backend
      final email = uniqueTestEmail();
      final userData = await backend.registerUser(
        email: email,
        password: 'password123',
        displayName: 'Geo Creator',
      );
      final token = userData['access_token'] as String;

      await backend.createGroup(
        token: token,
        name: 'Geofence Test Group',
      );

      await completeOnboardingAndGoToLogin(tester);

      // Login
      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        email,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'password123',
      );
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Groups tab
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();

      // Tap on the group
      await tester.tap(find.text('Geofence Test Group'));
      await tester.pumpAndSettle();

      // Tap "Add Geofence" or "Create Geofence" to navigate to create screen
      final addGeo = find.text('Add Geofence');
      final createGeo = find.text('Create Geofence');
      if (addGeo.evaluate().isNotEmpty) {
        await tester.tap(addGeo);
      } else if (createGeo.evaluate().isNotEmpty) {
        await tester.tap(createGeo);
      }
      await tester.pumpAndSettle();

      // Fill in geofence name
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Home Base',
      );

      // Radius already defaults to 200, leave it

      // Tap the map to select a location
      final mapFinder = find.byType(FlutterMap);
      await tester.tap(mapFinder);
      await tester.pumpAndSettle();

      // Tap the create FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify geofence appears in group detail
      expect(find.text('Home Base'), findsOneWidget);
    });
  });
}
