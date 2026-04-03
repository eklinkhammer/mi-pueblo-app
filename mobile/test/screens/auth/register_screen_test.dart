import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fence/l10n/app_localizations.dart';
import 'package:fence/providers/auth_provider.dart';
import 'package:fence/screens/auth/register_screen.dart';
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
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RegisterScreen(),
      ),
    );
  }

  group('RegisterScreen', () {
    testWidgets('renders Display Name, Email, and Password fields',
        (tester) async {
      await tester.pumpWidget(createApp());
      await tester.pumpAndSettle();

      expect(
          find.widgetWithText(TextField, 'Display Name'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
    });

    testWidgets('renders Create Account button', (tester) async {
      await tester.pumpWidget(createApp());
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Create Account'),
          findsOneWidget);
    });

    testWidgets('shows error message from auth state', (tester) async {
      await tester.pumpWidget(createApp());
      await tester.pumpAndSettle();

      notifier.setTestState(const AuthState(
        status: AuthStatus.unauthenticated,
        errorKey: AuthErrorKey.registrationFailed,
      ));
      await tester.pump();

      expect(find.text('Registration failed'), findsOneWidget);
    });

    testWidgets('shows "Already have an account? Sign in" link',
        (tester) async {
      await tester.pumpWidget(createApp());
      await tester.pumpAndSettle();

      expect(find.text('Already have an account? Sign in'), findsOneWidget);
    });
  });
}
