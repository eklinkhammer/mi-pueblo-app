import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fence/l10n/app_localizations.dart';
import 'package:fence/models/user.dart';
import 'package:fence/providers/auth_provider.dart';
import 'package:fence/services/location_service.dart';
import 'package:fence/screens/settings/settings_screen.dart';
import '../../helpers/mocks.dart';


class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.apiClient, super.localNotifications);

  void setTestState(AuthState newState) {
    // ignore: invalid_use_of_protected_member
    state = newState;
  }
}

final _testUser = User(
  id: 'user-1',
  email: 'alice@example.com',
  displayName: 'Alice',
  insertedAt: DateTime(2025),
);

void main() {
  late MockApiClient mockApi;
  late _TestAuthNotifier authNotifier;
  late MockLocationService mockLocationService;

  setUp(() {
    mockApi = MockApiClient();
    mockLocationService = MockLocationService();
    when(() => mockApi.getAccessToken()).thenAnswer((_) async => null);
    when(() => mockLocationService.startTracking()).thenAnswer((_) async {});
    when(() => mockLocationService.stopTracking()).thenAnswer((_) async {});
  });

  Widget createApp() {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) {
          authNotifier = _TestAuthNotifier(mockApi, MockLocalNotificationService());
          return authNotifier;
        }),
        locationServiceProvider
            .overrideWithValue(mockLocationService),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(),
      ),
    );
  }

  group('SettingsScreen', () {
    testWidgets('shows user display name and email', (tester) async {
      await tester.pumpWidget(createApp());
      await tester.pump();

      authNotifier.setTestState(AuthState(
        status: AuthStatus.authenticated,
        user: _testUser,
      ));
      await tester.pump();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('alice@example.com'), findsOneWidget);
    });

    testWidgets('shows Location Sharing toggle', (tester) async {
      await tester.pumpWidget(createApp());
      await tester.pump();

      expect(find.text('Location Sharing'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
    });

    testWidgets('toggle off calls stopTracking()', (tester) async {
      await tester.pumpWidget(createApp());
      await tester.pump();

      // Initial state is on; tapping toggles it off
      await tester.tap(find.byType(Switch));
      await tester.pump();

      verify(() => mockLocationService.stopTracking()).called(1);
    });

    testWidgets('toggle on calls startTracking()', (tester) async {
      await tester.pumpWidget(createApp());
      await tester.pump();

      // Tap once to turn off, then again to turn on
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.tap(find.byType(Switch));
      await tester.pump();

      verify(() => mockLocationService.startTracking()).called(1);
    });

    testWidgets('shows Location Permissions tile', (tester) async {
      await tester.pumpWidget(createApp());
      await tester.pump();

      expect(find.text('Location Permissions'), findsOneWidget);
    });

    testWidgets('shows Sign Out tile and tapping shows confirmation dialog',
        (tester) async {
      await tester.pumpWidget(createApp());
      await tester.pump();

      expect(find.text('Sign Out'), findsOneWidget);

      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      expect(find.text('Sign Out?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('cancel dialog keeps user logged in', (tester) async {
      await tester.pumpWidget(createApp());
      await tester.pump();

      authNotifier.setTestState(AuthState(
        status: AuthStatus.authenticated,
        user: _testUser,
      ));
      await tester.pump();

      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Still on settings screen with user info
      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('shows Unknown when no user', (tester) async {
      await tester.pumpWidget(createApp());
      await tester.pump();

      // Default state has no user
      expect(find.text('Unknown'), findsOneWidget);
    });
  });
}
