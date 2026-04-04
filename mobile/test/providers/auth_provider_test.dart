import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fence/providers/auth_provider.dart';
import '../helpers/mocks.dart';
import '../helpers/fakes.dart';
import '../helpers/test_data.dart';

void main() {
  late MockApiClient mockApi;
  late MockLocalNotificationService mockLocalNotifications;

  setUp(() {
    mockApi = MockApiClient();
    mockLocalNotifications = MockLocalNotificationService();
  });

  AuthNotifier createNotifier() =>
      AuthNotifier(mockApi, mockLocalNotifications);

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

    test('failure → error key set', () async {
      when(() => mockApi.getAccessToken()).thenAnswer((_) async => null);
      when(() => mockApi.login(any(), any())).thenThrow(Exception('bad'));

      final notifier = createNotifier();
      await Future<void>.delayed(Duration.zero);

      await notifier.login('alice@example.com', 'wrong');

      expect(notifier.state.errorKey, AuthErrorKey.invalidCredentials);
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

    test('failure → error key set', () async {
      when(() => mockApi.getAccessToken()).thenAnswer((_) async => null);
      when(() => mockApi.register(any(), any(), any()))
          .thenThrow(Exception('conflict'));

      final notifier = createNotifier();
      await Future<void>.delayed(Duration.zero);

      await notifier.register('alice@example.com', 'pass', 'Alice');

      expect(notifier.state.errorKey, AuthErrorKey.registrationFailed);
    });
  });

  group('AuthState', () {
    test('copyWith preserves fields correctly', () {
      const original = AuthState(
        status: AuthStatus.authenticated,
        user: null,
        errorKey: AuthErrorKey.invalidCredentials,
      );

      final updated = original.copyWith(status: AuthStatus.unauthenticated);

      expect(updated.status, AuthStatus.unauthenticated);
      expect(updated.user, isNull);
      // copyWith with no errorKey param clears the error (errorKey defaults to null)
      expect(updated.errorKey, isNull);
    });

    test('copyWith with explicit errorKey preserves it', () {
      const original = AuthState(status: AuthStatus.unknown);

      final updated = original.copyWith(
          status: AuthStatus.unauthenticated,
          errorKey: AuthErrorKey.registrationFailed);

      expect(updated.errorKey, AuthErrorKey.registrationFailed);
      expect(updated.status, AuthStatus.unauthenticated);
    });

    test('error cleared on subsequent state update', () async {
      when(() => mockApi.getAccessToken()).thenAnswer((_) async => null);
      when(() => mockApi.login(any(), any())).thenThrow(Exception('bad'));
      when(() => mockApi.register(any(), any(), any()))
          .thenThrow(Exception('also bad'));

      final notifier = createNotifier();
      await Future<void>.delayed(Duration.zero);

      // First action sets error
      await notifier.login('a@b.com', 'wrong');
      expect(notifier.state.errorKey, AuthErrorKey.invalidCredentials);

      // Second action sets different error, previous cleared
      await notifier.register('a@b.com', 'pass', 'Name');
      expect(notifier.state.errorKey, AuthErrorKey.registrationFailed);
    });
  });

  group('createGroupAsAnonymous', () {
    test('success → authenticated, returns group id', () async {
      when(() => mockApi.getAccessToken()).thenAnswer((_) async => null);
      when(() => mockApi.anonymousCreate(any(), any()))
          .thenAnswer((_) async => fakeResponse(anonymousCreateResponseJson));
      when(() => mockApi.setTokens(any(), any())).thenAnswer((_) async {});

      final notifier = createNotifier();
      await Future<void>.delayed(Duration.zero);

      final groupId =
          await notifier.createGroupAsAnonymous('New Group', 'Anon Creator');

      expect(groupId, '660e8400-e29b-41d4-a716-446655440099');
      expect(notifier.state.status, AuthStatus.authenticated);
      expect(notifier.state.user, isNotNull);
      expect(notifier.state.user!.displayName, 'Anon Creator');
      verify(() => mockApi.setTokens(
          'test-access-token', 'test-refresh-token')).called(1);
    });

    test('failure → returns null, error key set', () async {
      when(() => mockApi.getAccessToken()).thenAnswer((_) async => null);
      when(() => mockApi.anonymousCreate(any(), any()))
          .thenThrow(Exception('server error'));

      final notifier = createNotifier();
      await Future<void>.delayed(Duration.zero);

      final groupId =
          await notifier.createGroupAsAnonymous('Group', 'Name');

      expect(groupId, isNull);
      expect(notifier.state.errorKey, AuthErrorKey.anonymousCreateFailed);
    });
  });

  group('AuthState defaults', () {
    test('has correct default values', () {
      const state = AuthState();
      expect(state.status, AuthStatus.unknown);
      expect(state.user, isNull);
      expect(state.errorKey, isNull);
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
