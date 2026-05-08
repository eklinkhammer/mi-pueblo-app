import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fence/providers/auth_provider.dart';
import 'package:fence/providers/groups_provider.dart';
import 'package:fence/providers/visibility_provider.dart';
import 'package:fence/services/api_client.dart';
import '../helpers/mocks.dart';
import '../helpers/fakes.dart';
import '../helpers/test_data.dart';

void main() {
  late MockApiClient mockApi;
  late ProviderContainer container;

  group('visibilityProvider', () {
    setUp(() {
      mockApi = MockApiClient();
      container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(mockApi)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('fetches and parses visibility pairs', () async {
      when(() => mockApi.getVisibilityPairs(any())).thenAnswer((_) async =>
          fakeResponse({
            'visibility_pairs': [visibilityPairJson],
          }));

      final pairs =
          await container.read(visibilityProvider('group-id').future);

      expect(pairs, hasLength(1));
      expect(pairs.first.otherDisplayName, 'Bob');
      expect(pairs.first.status, 'active');
      expect(pairs.first.isActive, isTrue);
    });

    test('handles empty list', () async {
      when(() => mockApi.getVisibilityPairs(any())).thenAnswer((_) async =>
          fakeResponse(
              {'visibility_pairs': <Map<String, dynamic>>[]}));

      final pairs =
          await container.read(visibilityProvider('group-id').future);

      expect(pairs, isEmpty);
    });

    test('propagates API error', () async {
      when(() => mockApi.getVisibilityPairs(any()))
          .thenThrow(Exception('network error'));

      expect(
        () => container.read(visibilityProvider('group-id').future),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('toggleVisibility', () {
    setUp(() async {
      mockApi = MockApiClient();
      // Auth must be mocked because toggleVisibility invalidates groupsProvider,
      // which watches authProvider, which calls getAccessToken on build.
      when(() => mockApi.getAccessToken())
          .thenAnswer((_) async => 'test-token');
      when(() => mockApi.getMe()).thenAnswer(
          (_) async => fakeResponse({'user': userJson}));

      container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(mockApi)],
      );

      // Wait for auth to settle to authenticated
      container.read(authProvider);
      while (container.read(authProvider).status == AuthStatus.unknown) {
        await Future<void>.delayed(Duration.zero);
      }
    });

    tearDown(() {
      container.dispose();
    });

    test('calls API and invalidates self', () async {
      var fetchCount = 0;
      when(() => mockApi.getVisibilityPairs(any())).thenAnswer((_) async {
        fetchCount++;
        return fakeResponse({
          'visibility_pairs': [visibilityPairJson],
        });
      });
      when(() => mockApi.updateVisibility(any(), any(), visible: any(named: 'visible')))
          .thenAnswer((_) async => fakeResponse({'ok': true}));
      when(() => mockApi.getGroups()).thenAnswer((_) async =>
          fakeResponse({'groups': [groupJson]}));

      // Initial build
      await container.read(visibilityProvider('group-id').future);
      expect(fetchCount, 1);

      // Toggle
      await container
          .read(visibilityProvider('group-id').notifier)
          .toggleVisibility('group-id', 'other-user', visible: false);

      verify(() => mockApi.updateVisibility(
            'group-id',
            'other-user',
            visible: false,
          )).called(1);

      // Provider was invalidated, so reading again triggers a re-fetch
      await container.read(visibilityProvider('group-id').future);
      expect(fetchCount, greaterThan(1));
    });

    test('invalidates groupsProvider (sharing count sync)', () async {
      var groupsFetchCount = 0;
      when(() => mockApi.getGroups()).thenAnswer((_) async {
        groupsFetchCount++;
        return fakeResponse({
          'groups': [groupJson],
        });
      });
      when(() => mockApi.getVisibilityPairs(any())).thenAnswer((_) async =>
          fakeResponse({
            'visibility_pairs': [visibilityPairJson],
          }));
      when(() => mockApi.updateVisibility(any(), any(), visible: any(named: 'visible')))
          .thenAnswer((_) async => fakeResponse({'ok': true}));

      // Initial reads
      await container.read(groupsProvider.future);
      await container.read(visibilityProvider('group-id').future);
      expect(groupsFetchCount, 1);

      // Toggle visibility
      await container
          .read(visibilityProvider('group-id').notifier)
          .toggleVisibility('group-id', 'other-user', visible: false);

      // groupsProvider was invalidated, so reading again triggers re-fetch
      await container.read(groupsProvider.future);
      expect(groupsFetchCount, greaterThan(1));
    });
  });
}
