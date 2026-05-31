import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fence/models/app_location.dart';
import 'package:fence/services/deep_link_service.dart';
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

  /// Complete onboarding only (stay on /map, don't navigate to login).
  Future<void> completeOnboarding(WidgetTester tester) async {
    await pumpApp(tester, overrides: [
      locationServiceProvider.overrideWithValue(mockLocation),
    ]);

    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  /// Enter credentials and sign in.
  Future<void> login(
      WidgetTester tester, String email, String password) async {
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

  /// Get the ProviderContainer from the widget tree.
  ProviderContainer getContainer(WidgetTester tester) {
    final element = tester.element(find.byType(MaterialApp).first);
    return ProviderScope.containerOf(element);
  }

  group('Deep Link', () {
    testWidgets('Authenticated user — deep link pre-fills code and joins',
        (tester) async {
      // Backend setup: admin creates group + invite, joiner registers
      final adminEmail = uniqueTestEmail();
      final adminData = await backend.registerUser(
        email: adminEmail,
        password: 'password123',
        displayName: 'Admin',
      );
      final adminToken = adminData['access_token'] as String;

      final group = await backend.createGroup(
        token: adminToken,
        name: 'Deep Link Family',
      );

      final invite = await backend.createInvite(
        token: adminToken,
        groupId: group['id'] as String,
      );
      final inviteCode = invite['code'] as String;

      final joinerEmail = uniqueTestEmail();
      await backend.registerUser(
        email: joinerEmail,
        password: 'password123',
        displayName: 'Joiner',
      );

      // Complete onboarding and login
      await completeOnboardingAndGoToLogin(tester);
      await login(tester, joinerEmail, 'password123');

      // Navigate to Groups tab, verify empty state
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();

      // Simulate deep link by setting pendingInviteCodeProvider
      final container = getContainer(tester);
      container.read(pendingInviteCodeProvider.notifier).state = inviteCode;
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should land on /groups/join with code pre-filled
      expect(find.widgetWithText(TextField, 'Invite Code'), findsOneWidget);

      // Verify the code is pre-filled in the text field
      final textField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Invite Code'),
      );
      expect(textField.controller?.text, inviteCode);

      // Tap "Join Group" button
      await tester.tap(find.widgetWithText(FilledButton, 'Join Group'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Should be on group detail screen
      expect(find.text('Members'), findsOneWidget);

      // Navigate back to groups list, verify group appears
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();
      expect(find.text('Deep Link Family'), findsOneWidget);
    });

    testWidgets(
        'Unauthenticated user — deep link pre-fills code on anonymous join',
        (tester) async {
      // Backend setup: admin creates group + invite
      final adminEmail = uniqueTestEmail();
      final adminData = await backend.registerUser(
        email: adminEmail,
        password: 'password123',
        displayName: 'Admin',
      );
      final adminToken = adminData['access_token'] as String;

      final group = await backend.createGroup(
        token: adminToken,
        name: 'Anon Deep Link Family',
      );

      final invite = await backend.createInvite(
        token: adminToken,
        groupId: group['id'] as String,
      );
      final inviteCode = invite['code'] as String;

      // Complete onboarding only (don't login)
      await completeOnboarding(tester);

      // Simulate deep link by setting pendingInviteCodeProvider
      final container = getContainer(tester);
      container.read(pendingInviteCodeProvider.notifier).state = inviteCode;
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should land on /auth/join with code pre-filled
      expect(find.widgetWithText(TextField, 'Group Code'), findsOneWidget);

      // Verify the code is pre-filled
      final codeField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Group Code'),
      );
      expect(codeField.controller?.text, inviteCode);

      // Enter a name and tap "Join"
      await tester.enterText(
        find.widgetWithText(TextField, 'Your Name'),
        'Deep Linker',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Join'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // After anonymous join succeeds, auth status becomes authenticated
      // and router redirects to /map
      expect(find.byType(Scaffold), findsWidgets);

      // Navigate to Groups tab to verify the user is in the group
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();
      expect(find.text('Anon Deep Link Family'), findsOneWidget);
    });

    testWidgets('Share button appears in invite dialog', (tester) async {
      // Backend setup: register user, create group
      final email = uniqueTestEmail();
      await backend.registerUser(
        email: email,
        password: 'password123',
        displayName: 'Sharer',
      );

      await completeOnboardingAndGoToLogin(tester);
      await login(tester, email, 'password123');

      // Create a group through the UI
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();

      final createAGroup = find.text('Create a Group');
      if (createAGroup.evaluate().isNotEmpty) {
        await tester.tap(createAGroup);
      } else {
        await tester.tap(find.byIcon(Icons.add));
      }
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Group Name'),
        'Share Test Group',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create Group'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Now on group detail screen — tap invite button
      await tester.tap(find.byIcon(Icons.person_add));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify invite dialog has Share, Copy, and Done buttons
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('Invite response includes URL', (tester) async {
      // Pure backend test — no UI needed, but using testWidgets for consistency
      final email = uniqueTestEmail();
      final userData = await backend.registerUser(
        email: email,
        password: 'password123',
        displayName: 'URL Tester',
      );
      final token = userData['access_token'] as String;

      final group = await backend.createGroup(
        token: token,
        name: 'URL Test Group',
      );

      final invite = await backend.createInvite(
        token: token,
        groupId: group['id'] as String,
      );

      // Verify invite contains url key
      expect(invite.containsKey('url'), isTrue);

      // Verify URL format contains the invite code
      final url = invite['url'] as String;
      final code = invite['code'] as String;
      expect(url, contains('/join/$code'));
    });
  });
}
