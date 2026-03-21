import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/backend_client.dart';
import 'helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final backend = BackendTestClient();

  group('Group Lifecycle', () {
    testWidgets('Create group through UI', (tester) async {
      // Pre-create and login user
      final email = uniqueTestEmail();
      await backend.registerUser(
        email: email,
        password: 'password123',
        displayName: 'Group Creator',
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

      // Navigate to Groups tab
      await tester.tap(find.byIcon(Icons.group));
      await tester.pumpAndSettle();

      // Tap create group button (FAB or button)
      final createButton = find.byIcon(Icons.add);
      if (createButton.evaluate().isNotEmpty) {
        await tester.tap(createButton.first);
        await tester.pumpAndSettle();
      }

      // Fill in group name
      await tester.enterText(
        find.widgetWithText(TextField, 'Group Name'),
        'My Family',
      );

      // Submit
      final submitButton = find.text('Create');
      if (submitButton.evaluate().isNotEmpty) {
        await tester.tap(submitButton);
      } else {
        await tester.tap(find.text('Create Group'));
      }
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify group appears in list
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

      // Create and login as the joining user
      final joinerEmail = uniqueTestEmail();
      await backend.registerUser(
        email: joinerEmail,
        password: 'password123',
        displayName: 'Joiner',
      );

      await pumpApp(tester);

      // Login
      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        joinerEmail,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'password123',
      );
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Groups tab
      await tester.tap(find.byIcon(Icons.group));
      await tester.pumpAndSettle();

      // Tap join group
      final joinButton = find.text('Join Group');
      if (joinButton.evaluate().isNotEmpty) {
        await tester.tap(joinButton);
        await tester.pumpAndSettle();
      }

      // Enter invite code
      await tester.enterText(
        find.widgetWithText(TextField, 'Invite Code'),
        inviteCode,
      );

      // Submit
      final submitButton = find.text('Join');
      if (submitButton.evaluate().isNotEmpty) {
        await tester.tap(submitButton);
      }
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Group should appear
      expect(find.text('Test Family'), findsOneWidget);
    });
  });
}
