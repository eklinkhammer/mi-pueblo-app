import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';
import 'helpers/mock_api_setup.dart';

void main() {
  late MockApiClient mockApi;

  setUpAll(registerFallbacks);

  setUp(() {
    mockApi = MockApiClient();
  });

  group('Auth flow', () {
    testWidgets('unauthenticated user sees map with CTA', (tester) async {
      setupUnauthenticatedStubs(mockApi);

      await pumpAppWithMocks(tester, apiClient: mockApi);

      // Should be on the map screen with anonymous CTA
      expect(find.text('Join Group'), findsOneWidget);
    });

    testWidgets('login with valid credentials navigates to map',
        (tester) async {
      setupUnauthenticatedStubs(mockApi);
      setupLoginStubs(mockApi);
      setupGroupStubs(mockApi);
      setupGeofenceStubs(mockApi);
      setupLocationStubs(mockApi);

      await pumpAppWithMocks(tester, apiClient: mockApi);

      // Navigate: map CTA → join sheet → register → login
      await tester.tap(find.text('Join Group'));
      await tester.pumpAndSettle();

      // Drag the sheet up to reveal "Create a Group" button
      await tester.drag(find.text('Mi Pueblo'), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create a Group'));
      await tester.pumpAndSettle();

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

      // Should now be on the authenticated map screen
      expect(find.text('Select a group to view the map'), findsOneWidget);
    });

    testWidgets('login with invalid credentials shows error', (tester) async {
      setupUnauthenticatedStubs(mockApi);
      setupLoginFailureStubs(mockApi);

      await pumpAppWithMocks(tester, apiClient: mockApi);

      // Navigate: map CTA → join sheet → register → login
      await tester.tap(find.text('Join Group'));
      await tester.pumpAndSettle();

      // Drag the sheet up to reveal "Create a Group" button
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
      setupRegisterStubs(mockApi);
      setupGroupStubs(mockApi);
      setupGeofenceStubs(mockApi);
      setupLocationStubs(mockApi);

      await pumpAppWithMocks(tester, apiClient: mockApi);

      // Navigate from map CTA → join sheet → register
      await tester.tap(find.text('Join Group'));
      await tester.pumpAndSettle();

      // Drag the sheet up to reveal "Create a Group" button
      await tester.drag(find.text('Mi Pueblo'), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create a Group'));
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

      // Should navigate to map
      expect(find.text('Select a group to view the map'), findsOneWidget);
    });

    testWidgets('logout from settings returns to map with CTA',
        (tester) async {
      setupAuthenticatedStubs(mockApi);
      setupGroupStubs(mockApi);
      setupGeofenceStubs(mockApi);
      setupLocationStubs(mockApi);

      await pumpAppWithMocks(tester, apiClient: mockApi);

      // Should be on map (authenticated)
      expect(find.text('Select a group to view the map'), findsOneWidget);

      // Navigate to Settings tab
      await tester.tap(find.text('Settings'));
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

      // Should be on map with anonymous CTA
      expect(find.text('Join Group'), findsOneWidget);
    });

    testWidgets('login → logout → re-login cycle', (tester) async {
      setupUnauthenticatedStubs(mockApi);
      setupLoginStubs(mockApi);
      setupGroupStubs(mockApi);
      setupGeofenceStubs(mockApi);
      setupLocationStubs(mockApi);

      await pumpAppWithMocks(tester, apiClient: mockApi);

      // === Navigate: map CTA → join sheet → register → login ===
      await tester.tap(find.text('Join Group'));
      await tester.pumpAndSettle();

      // Drag the sheet up to reveal "Create a Group" button
      await tester.drag(find.text('Mi Pueblo'), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create a Group'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Already have an account? Sign in'));
      await tester.pumpAndSettle();

      // === First login ===
      await tester.enterText(
          find.widgetWithText(TextField, 'Email'), 'alice@example.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Password'), 'password123');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Select a group to view the map'), findsOneWidget);

      // === Logout ===
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Sign Out'));
      when(() => mockApi.getAccessToken()).thenAnswer((_) async => null);
      await tester.pumpAndSettle();

      // Should be on map with anonymous CTA after logout
      expect(find.text('Join Group'), findsOneWidget);

      // Navigate: map CTA → join sheet → register → login
      await tester.tap(find.text('Join Group'));
      await tester.pumpAndSettle();

      // Drag the sheet up to reveal "Create a Group" button
      await tester.drag(find.text('Mi Pueblo'), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create a Group'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Already have an account? Sign in'));
      await tester.pumpAndSettle();

      // === Re-login ===
      await tester.enterText(
          find.widgetWithText(TextField, 'Email'), 'alice@example.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Password'), 'password123');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Select a group to view the map'), findsOneWidget);
    });
  });
}
