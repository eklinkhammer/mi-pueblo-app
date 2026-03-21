import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/backend_client.dart';
import 'helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final backend = BackendTestClient();

  group('Auth Flow', () {
    testWidgets('Register through UI', (tester) async {
      await pumpApp(tester);

      // Should start on login screen (unauthenticated)
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

      // Submit
      await tester.tap(find.text('Create Account'));
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

      await pumpApp(tester);

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

      await pumpApp(tester);

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

      // Navigate to settings
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      // Tap logout
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();

      // Should be back on login screen
      expect(find.text('Sign In'), findsOneWidget);

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
