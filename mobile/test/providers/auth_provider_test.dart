import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fence/providers/auth_provider.dart';
import 'package:fence/services/api_client.dart';
import '../helpers/mocks.dart';
import '../helpers/fakes.dart';
import '../helpers/test_data.dart';

void main() {
  late MockApiClient mockApi;

  setUp(() {
    mockApi = MockApiClient();
  });

  AuthNotifier createNotifier() => AuthNotifier(mockApi);

  group('initial _checkAuth', () {
    test('no token → unauthenticated', () async {
      when(() => mockApi.getAccessToken()).thenAnswer((_) async => null);

      final notifier = createNotifier();
      // Pump the event loop so _checkAuth completes
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.status, AuthStatus.unauthenticated);
      expect(notifier.state.user, isNull);
    });

    test('token exists + getMe succeeds → authenticated', () async {
      when(() => mockApi.getAccessToken())
          .thenAnswer((_) async => 'valid-token');
      when(() => mockApi.getMe())
          .thenAnswer((_) async => fakeResponse({'user': userJson}));

      final notifier = createNotifier();
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.status, AuthStatus.authenticated);
      expect(notifier.state.user, isNotNull);
      expect(notifier.state.user!.email, 'alice@example.com');
    });

    test('token exists + getMe throws → unauthenticated', () async {
      when(() => mockApi.getAccessToken())
          .thenAnswer((_) async => 'expired-token');
      when(() => mockApi.getMe()).thenThrow(Exception('401'));

      final notifier = createNotifier();
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.status, AuthStatus.unauthenticated);
    });
  });

  group('login', () {
    test('success → authenticated with user', () async {
      when(() => mockApi.getAccessToken()).thenAnswer((_) async => null);
      when(() => mockApi.login(any(), any()))
          .thenAnswer((_) async => fakeResponse(loginResponseJson));
      when(() => mockApi.setTokens(any(), any())).thenAnswer((_) async {});

      final notifier = createNotifier();
      await Future<void>.delayed(Duration.zero);

      await notifier.login('alice@example.com', 'password123');

      expect(notifier.state.status, AuthStatus.authenticated);
      expect(notifier.state.user!.displayName, 'Alice');
      verify(() => mockApi.setTokens(
          'test-access-token', 'test-refresh-token')).called(1);
    });

    test('failure → error message', () async {
      when(() => mockApi.getAccessToken()).thenAnswer((_) async => null);
      when(() => mockApi.login(any(), any())).thenThrow(Exception('bad'));

      final notifier = createNotifier();
      await Future<void>.delayed(Duration.zero);

      await notifier.login('alice@example.com', 'wrong');

      expect(notifier.state.error, 'Invalid email or password');
    });
  });

  group('register', () {
    test('success → authenticated with user', () async {
      when(() => mockApi.getAccessToken()).thenAnswer((_) async => null);
      when(() => mockApi.register(any(), any(), any()))
          .thenAnswer((_) async => fakeResponse(registerResponseJson));
      when(() => mockApi.setTokens(any(), any())).thenAnswer((_) async {});

      final notifier = createNotifier();
      await Future<void>.delayed(Duration.zero);

      await notifier.register('alice@example.com', 'password123', 'Alice');

      expect(notifier.state.status, AuthStatus.authenticated);
      expect(notifier.state.user!.email, 'alice@example.com');
    });

    test('failure → error message', () async {
      when(() => mockApi.getAccessToken()).thenAnswer((_) async => null);
      when(() => mockApi.register(any(), any(), any()))
          .thenThrow(Exception('conflict'));

      final notifier = createNotifier();
      await Future<void>.delayed(Duration.zero);

      await notifier.register('alice@example.com', 'pass', 'Alice');

      expect(notifier.state.error, 'Registration failed');
    });
  });

  group('logout', () {
    test('clears state to unauthenticated', () async {
      when(() => mockApi.getAccessToken())
          .thenAnswer((_) async => 'valid-token');
      when(() => mockApi.getMe())
          .thenAnswer((_) async => fakeResponse({'user': userJson}));
      when(() => mockApi.clearTokens()).thenAnswer((_) async {});

      final notifier = createNotifier();
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.status, AuthStatus.authenticated);

      await notifier.logout();

      expect(notifier.state.status, AuthStatus.unauthenticated);
      expect(notifier.state.user, isNull);
      verify(() => mockApi.clearTokens()).called(1);
    });
  });
}
