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
        .thenAnswer((_) async => PermissionStatus.granted);
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

  /// Enter credentials and sign in.
  Future<void> login(WidgetTester tester, String email, String password) async {
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      email,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      password,
    );
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }

  group('Group Lifecycle', () {
    testWidgets('Create group through UI', (tester) async {
      // Pre-create and login user
      final email = uniqueTestEmail();
      await backend.registerUser(
        email: email,
        password: 'password123',
        displayName: 'Group Creator',
      );

      await completeOnboardingAndGoToLogin(tester);
      await login(tester, email, 'password123');

      // Navigate to Groups tab
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();

      // Tap "Create a Group" button (empty state) or FAB
      final createAGroup = find.text('Create a Group');
      if (createAGroup.evaluate().isNotEmpty) {
        await tester.tap(createAGroup);
      } else {
        await tester.tap(find.byIcon(Icons.add));
      }
      await tester.pumpAndSettle();

      // Fill in group name
      await tester.enterText(
        find.widgetWithText(TextField, 'Group Name'),
        'My Family',
      );

      // Submit — use FilledButton to avoid ambiguity with AppBar title
      await tester.tap(find.widgetWithText(FilledButton, 'Create Group'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // After create, navigates to group detail screen
      expect(find.text('Members'), findsOneWidget);

      // Navigate back to groups list to verify it appears
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();
      expect(find.text('My Family'), findsOneWidget);
    });

    testWidgets('Join group via invite code', (tester) async {
      // Pre-create group + invite via backend
      final adminEmail = uniqueTestEmail();
      final adminData = await backend.registerUser(
        email: adminEmail,
        password: 'password123',
        displayName: 'Admin',
      );
      final adminToken = adminData['access_token'] as String;

      final group = await backend.createGroup(
        token: adminToken,
        name: 'Test Family',
      );

      final invite = await backend.createInvite(
        token: adminToken,
        groupId: group['id'] as String,
      );
      final inviteCode = invite['code'] as String;

      // Create the joining user via backend
      final joinerEmail = uniqueTestEmail();
      await backend.registerUser(
        email: joinerEmail,
        password: 'password123',
        displayName: 'Joiner',
      );

      await completeOnboardingAndGoToLogin(tester);
      await login(tester, joinerEmail, 'password123');

      // Navigate to Groups tab
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();

      // Tap "Join with Invite Code" button (empty state) or group_add icon
      final joinWithCode = find.text('Join with Invite Code');
      if (joinWithCode.evaluate().isNotEmpty) {
        await tester.tap(joinWithCode);
      } else {
        await tester.tap(find.byIcon(Icons.group_add));
      }
      await tester.pumpAndSettle();

      // Enter invite code
      await tester.enterText(
        find.widgetWithText(TextField, 'Invite Code'),
        inviteCode,
      );

      // Submit — use FilledButton to avoid ambiguity with AppBar title
      await tester.tap(find.widgetWithText(FilledButton, 'Join Group'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // After join, navigates to group detail screen
      expect(find.text('Members'), findsOneWidget);

      // Navigate back to groups list to verify it appears
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();
      expect(find.text('Test Family'), findsOneWidget);
    });

    testWidgets('Leave group through UI', (tester) async {
      // Admin creates group + invite via backend
      final adminEmail = uniqueTestEmail();
      final adminData = await backend.registerUser(
        email: adminEmail,
        password: 'password123',
        displayName: 'Admin',
      );
      final adminToken = adminData['access_token'] as String;

      final group = await backend.createGroup(
        token: adminToken,
        name: 'Leave Test Family',
      );
      final groupId = group['id'] as String;

      final invite = await backend.createInvite(
        token: adminToken,
        groupId: groupId,
      );
      final inviteCode = invite['code'] as String;

      // Member registers + joins via backend
      final memberEmail = uniqueTestEmail();
      final memberData = await backend.registerUser(
        email: memberEmail,
        password: 'password123',
        displayName: 'Member',
      );
      final memberToken = memberData['access_token'] as String;
      await backend.joinGroup(token: memberToken, inviteCode: inviteCode);

      // Member logs in via UI
      await completeOnboardingAndGoToLogin(tester);
      await login(tester, memberEmail, 'password123');

      // Navigate to Groups tab
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();

      // Tap the group
      await tester.tap(find.text('Leave Test Family'));
      await tester.pumpAndSettle();

      // Tap leave button
      await tester.tap(find.byIcon(Icons.exit_to_app));
      await tester.pumpAndSettle();

      // Confirm leave
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Group should be gone from list
      expect(find.text('Leave Test Family'), findsNothing);
    });
  });
}
