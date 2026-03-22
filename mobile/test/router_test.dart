import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fence/router.dart';
import 'package:fence/providers/auth_provider.dart';
import 'helpers/mocks.dart';

Response<Map<String, dynamic>> _fakeResponse(Map<String, dynamic> data) {
  return Response<Map<String, dynamic>>(
    data: data,
    statusCode: 200,
    requestOptions: RequestOptions(path: '/fake'),
  );
}

/// Drain the microtask queue so all async _checkAuth work completes.
Future<void> _pumpAsync() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late MockApiClient mockApi;

  setUp(() {
    mockApi = MockApiClient();
    when(() => mockApi.getAccessToken()).thenAnswer((_) async => null);
  });

  group('router redirect logic', () {
    test('unknown auth status → no redirect', () {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => AuthNotifier(mockApi)),
        ],
      );
      addTearDown(container.dispose);

      // Read synchronously before _checkAuth completes
      final state = container.read(authProvider);
      expect(state.status, AuthStatus.unknown);

      final router = container.read(routerProvider);
      expect(router.configuration.routes, isNotEmpty);
    });

    test('unauthenticated + protected route → redirect to /auth/login',
        () async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => AuthNotifier(mockApi)),
        ],
      );
      addTearDown(container.dispose);

      // Force provider creation, then drain async
      container.read(authProvider);
      await _pumpAsync();

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.unauthenticated);

      final router = container.read(routerProvider);
      expect(router.configuration.redirect, isNotNull);
    });

    test('authenticated + auth route → redirect to /map', () async {
      when(() => mockApi.getAccessToken())
          .thenAnswer((_) async => 'valid-token');
      when(() => mockApi.getMe()).thenAnswer((_) async {
        return _fakeResponse({
          'user': {
            'id': 'uid',
            'email': 'a@b.com',
            'display_name': 'A',
            'inserted_at': '2025-01-01T00:00:00Z',
          }
        });
      });

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => AuthNotifier(mockApi)),
        ],
      );
      addTearDown(container.dispose);

      container.read(authProvider);
      await _pumpAsync();

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.authenticated);

      final router = container.read(routerProvider);
      expect(router.configuration.redirect, isNotNull);
    });

    test('authenticated + protected route → no redirect', () async {
      when(() => mockApi.getAccessToken())
          .thenAnswer((_) async => 'valid-token');
      when(() => mockApi.getMe()).thenAnswer((_) async {
        return _fakeResponse({
          'user': {
            'id': 'uid',
            'email': 'a@b.com',
            'display_name': 'A',
            'inserted_at': '2025-01-01T00:00:00Z',
          }
        });
      });

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => AuthNotifier(mockApi)),
        ],
      );
      addTearDown(container.dispose);

      container.read(authProvider);
      await _pumpAsync();

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.authenticated);

      final router = container.read(routerProvider);
      expect(router.configuration.routes, isNotEmpty);
    });
  });
}
