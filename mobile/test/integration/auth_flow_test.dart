import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';
import '../helpers/test_data.dart';
import 'helpers/mock_api_setup.dart';

void main() {
  late MockApiClient mockApi;

  setUpAll(registerFallbacks);

  setUp(() {
    mockApi = MockApiClient();
  });

  group('Auth flow', () {
    testWidgets('unauthenticated user sees map with join CTA', (tester) async {
      setupUnauthenticatedStubs(mockApi);
      setupGroupStubs(mockApi);

      await pumpAppWithMocks(tester, apiClient: mockApi);

      // Should be on the map screen with join CTA
      expect(find.text('Join My Village'), findsOneWidget);
    });

    testWidgets('login with valid credentials navigates to map',
        (tester) async {
      setupUnauthenticatedStubs(mockApi);
      setupGroupStubs(mockApi);
      setupGeofenceStubs(mockApi);
      setupLocationStubs(mockApi);
      setupLoginStubs(mockApi);

      await pumpAppWithMocks(tester, apiClient: mockApi);

      // Navigate: map CTA → join sheet → create → auth/create → login
      await tester.tap(find.text('Join My Village'));
      await tester.pumpAndSettle();

      // Drag the sheet up to reveal "Create a Group" button
      await tester.drag(find.text('Mi Pueblo'), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create a Group'));
      await tester.pumpAndSettle();

      // On AnonymousCreateScreen: go to login
      await tester.tap(find.text('Already have an account? Sign in'));
      await tester.pumpAndSettle();

      // We should be on the login screen
      expect(find.text('Sign In'), findsOneWidget);

      // Enter credentials
      await tester.enterText(
          find.widgetWithText(TextField, 'Email'), 'alice@example.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Password'), 'password123');

      // Tap sign in
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // Should now be on the authenticated map (bottom nav visible)
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('login with invalid credentials shows error', (tester) async {
      setupUnauthenticatedStubs(mockApi);
      setupGroupStubs(mockApi);
      setupLoginFailureStubs(mockApi);

      await pumpAppWithMocks(tester, apiClient: mockApi);

      // Navigate: map CTA → join sheet → create → auth/create → login
      await tester.tap(find.text('Join My Village'));
      await tester.pumpAndSettle();

      await tester.drag(find.text('Mi Pueblo'), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create a Group'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Already have an account? Sign in'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Email'), 'wrong@example.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Password'), 'bad');

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // Error message from AuthNotifier
      expect(find.text('Invalid email or password'), findsOneWidget);
      // Still on login screen
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('navigate to register, fill form, submit navigates to map',
        (tester) async {
      setupUnauthenticatedStubs(mockApi);
      setupGroupStubs(mockApi);
      setupGeofenceStubs(mockApi);
      setupLocationStubs(mockApi);
      setupRegisterStubs(mockApi);

      await pumpAppWithMocks(tester, apiClient: mockApi);

      // Navigate: map CTA → join sheet → create → auth/create → login → register
      await tester.tap(find.text('Join My Village'));
      await tester.pumpAndSettle();

      await tester.drag(find.text('Mi Pueblo'), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create a Group'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Already have an account? Sign in'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      // Should be on register screen
      expect(find.text('Create Account'), findsWidgets);

      // Fill in registration form
      await tester.enterText(
          find.widgetWithText(TextField, 'Display Name'), 'Alice');
      await tester.enterText(
          find.widgetWithText(TextField, 'Email'), 'alice@example.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Password'), 'password123');

      // Submit
      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.pumpAndSettle();

      // Should navigate to authenticated map (bottom nav visible)
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('logout from settings returns to unauthenticated state',
        (tester) async {
      setupAuthenticatedStubs(mockApi);
      // Need non-empty groups so settings icon appears on map
      setupGroupStubs(mockApi, groups: [groupJson]);
      setupGeofenceStubs(mockApi);
      setupLocationStubs(mockApi);

      await pumpAppWithMocks(tester, apiClient: mockApi);

      // Should be on map (authenticated, nav bar visible)
      expect(find.byType(NavigationBar), findsOneWidget);

      // Navigate to Settings via icon button on map
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);

      // Tap Sign Out
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      // Confirm dialog appears
      expect(find.text('Sign Out?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Sign Out'));

      // After logout, mock should return unauthenticated on next check
      when(() => mockApi.getAccessToken()).thenAnswer((_) async => null);
      await tester.pumpAndSettle();

      // Should be unauthenticated (no nav bar)
      expect(find.byType(NavigationBar), findsNothing);
    });
  });
}
