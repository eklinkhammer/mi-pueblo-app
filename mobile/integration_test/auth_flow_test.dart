import 'package:flutter/material.dart';
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

    // Now on /map (anonymous) — tap "Join Group" to open join sheet
    await tester.tap(find.text('Join Group'));
    await tester.pumpAndSettle();

    // Tap "Create a Group" to navigate to /auth/create
    await tester.tap(find.text('Create a Group'));
    await tester.pumpAndSettle();

    // Now on /auth/create — tap "Already have an account?" to go to login
    await tester.tap(find.text('Already have an account? Sign in'));
    await tester.pumpAndSettle();
  }

  group('Auth Flow', () {
    testWidgets('Register through UI', (tester) async {
      await completeOnboardingAndGoToLogin(tester);

      // Should be on login screen
      expect(find.text('Sign In'), findsOneWidget);

      // Navigate to register
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      // Fill in registration form
      final email = uniqueTestEmail();
      await tester.enterText(
        find.widgetWithText(TextField, 'Display Name'),
        'Integration Tester',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        email,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'password123',
      );

      // Submit (use FilledButton finder since AppBar also has "Create Account")
      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Should navigate to map screen after successful registration
      expect(find.text('Sign In'), findsNothing);
    });

    testWidgets('Login through UI with pre-created user', (tester) async {
      // Pre-create user via backend
      final email = uniqueTestEmail();
      await backend.registerUser(
        email: email,
        password: 'password123',
        displayName: 'Pre-Created User',
      );

      await completeOnboardingAndGoToLogin(tester);

      // Should be on login screen
      expect(find.text('Sign In'), findsOneWidget);

      // Fill in login form
      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        email,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'password123',
      );

      // Submit
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Should navigate away from login screen
      expect(find.text('Sign In'), findsNothing);
    });

    testWidgets('Logout and re-login', (tester) async {
      // Pre-create user
      final email = uniqueTestEmail();
      await backend.registerUser(
        email: email,
        password: 'password123',
        displayName: 'Logout Tester',
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

      // Navigate to settings via bottom nav label
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Tap sign out ListTile
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      // Confirm sign out dialog (FilledButton in dialog)
      await tester.tap(find.widgetWithText(FilledButton, 'Sign Out'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // After logout, ends up on /map (unauthenticated)
      // Navigate to login through the same flow
      await tester.tap(find.text('Join Group'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create a Group'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Already have an account? Sign in'));
      await tester.pumpAndSettle();

      // Re-login
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

      // Should be authenticated again
      expect(find.text('Sign In'), findsNothing);
    });
  });
}
