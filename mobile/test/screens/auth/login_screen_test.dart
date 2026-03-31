import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fence/l10n/app_localizations.dart';
import 'package:fence/providers/auth_provider.dart';
import 'package:fence/screens/auth/login_screen.dart';
import '../../helpers/mocks.dart';

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.apiClient);

  void setTestState(AuthState newState) {
    // ignore: invalid_use_of_protected_member
    state = newState;
  }
}

void main() {
  late MockApiClient mockApi;
  late _TestAuthNotifier notifier;

  setUp(() {
    mockApi = MockApiClient();
    when(() => mockApi.getAccessToken()).thenAnswer((_) async => null);
  });

  Widget createApp() {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) {
          notifier = _TestAuthNotifier(mockApi);
          return notifier;
        }),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LoginScreen(),
      ),
    );
  }

  group('LoginScreen', () {
    testWidgets('renders email and password fields', (tester) async {
      await tester.pumpWidget(createApp());
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
    });

    testWidgets('renders Sign In button', (tester) async {
      await tester.pumpWidget(createApp());
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Sign In'), findsOneWidget);
    });

    testWidgets('shows error message when error is set', (tester) async {
      await tester.pumpWidget(createApp());
      await tester.pumpAndSettle();

      notifier.setTestState(
        const AuthState(
          status: AuthStatus.unauthenticated,
          errorKey: AuthErrorKey.invalidCredentials,
        ),
      );
      await tester.pump(); // rebuild with error

      expect(find.text('Invalid email or password'), findsOneWidget);
    });

    testWidgets('shows Create an account link', (tester) async {
      await tester.pumpWidget(createApp());
      await tester.pumpAndSettle();

      expect(find.text('Create an account'), findsOneWidget);
    });
  });
}
