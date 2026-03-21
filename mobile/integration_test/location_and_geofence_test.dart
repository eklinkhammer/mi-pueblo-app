import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/backend_client.dart';
import 'helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final backend = BackendTestClient();

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

      final group = await backend.createGroup(
        token: token,
        name: 'Geofence Test Group',
      );
      final groupId = group['id'] as String;

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

      // Tap on the group
      await tester.tap(find.text('Geofence Test Group'));
      await tester.pumpAndSettle();

      // Tap create geofence button
      final createGeoButton = find.text('Create Geofence');
      if (createGeoButton.evaluate().isNotEmpty) {
        await tester.tap(createGeoButton);
        await tester.pumpAndSettle();
      } else {
        // Try FAB
        final fab = find.byIcon(Icons.add);
        if (fab.evaluate().isNotEmpty) {
          await tester.tap(fab.first);
          await tester.pumpAndSettle();
        }
      }

      // Fill in geofence form
      final nameField = find.widgetWithText(TextField, 'Name');
      if (nameField.evaluate().isNotEmpty) {
        await tester.enterText(nameField, 'Home Base');
      }

      final latField = find.widgetWithText(TextField, 'Latitude');
      if (latField.evaluate().isNotEmpty) {
        await tester.enterText(latField, '37.7749');
      }

      final lngField = find.widgetWithText(TextField, 'Longitude');
      if (lngField.evaluate().isNotEmpty) {
        await tester.enterText(lngField, '-122.4194');
      }

      final radiusField = find.widgetWithText(TextField, 'Radius');
      if (radiusField.evaluate().isNotEmpty) {
        await tester.enterText(radiusField, '500');
      }

      // Submit
      final submitButton = find.text('Create');
      if (submitButton.evaluate().isNotEmpty) {
        await tester.tap(submitButton);
      } else {
        final saveButton = find.text('Save');
        if (saveButton.evaluate().isNotEmpty) {
          await tester.tap(saveButton);
        }
      }
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify geofence appears in list
      expect(find.text('Home Base'), findsOneWidget);
    });
  });
}
