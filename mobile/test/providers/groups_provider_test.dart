import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fence/providers/auth_provider.dart';
import 'package:fence/providers/groups_provider.dart';
import 'package:fence/services/api_client.dart';
import '../helpers/mocks.dart';
import '../helpers/fakes.dart';
import '../helpers/test_data.dart';

void main() {
  late MockApiClient mockApi;
  late ProviderContainer container;

  setUp(() async {
    mockApi = MockApiClient();
    when(() => mockApi.getAccessToken())
        .thenAnswer((_) async => 'test-token');
    when(() => mockApi.getMe()).thenAnswer(
        (_) async => fakeResponse({'user': userJson}));
    container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(mockApi)],
    );
    // Trigger auth check and pump until it settles to authenticated
    container.read(authProvider);
    while (container.read(authProvider).status == AuthStatus.unknown) {
      await Future<void>.delayed(Duration.zero);
    }
  });

  tearDown(() {
    container.dispose();
  });

  group('groupsProvider', () {
    test('build() fetches and parses groups', () async {
      when(() => mockApi.getGroups()).thenAnswer((_) async => fakeResponse({
            'groups': [groupJson],
          }));

      final groups = await container.read(groupsProvider.future);

      expect(groups, hasLength(1));
      expect(groups.first.name, 'Family');
    });

    test('build() handles empty list', () async {
      when(() => mockApi.getGroups()).thenAnswer(
          (_) async => fakeResponse({'groups': <Map<String, dynamic>>[]}));

      final groups = await container.read(groupsProvider.future);

      expect(groups, isEmpty);
    });

    test('build() propagates error', () async {
      when(() => mockApi.getGroups()).thenThrow(Exception('network error'));

      await expectLater(
        container.read(groupsProvider.future),
        throwsA(isA<Exception>()),
      );
    });

    test('createGroup triggers refresh', () async {
      var callCount = 0;
      when(() => mockApi.getGroups()).thenAnswer((_) async {
        callCount++;
        return fakeResponse({
          'groups': [groupJson],
        });
      });
      when(() => mockApi.createGroup(any()))
          .thenAnswer((_) async => fakeResponse({'group': groupJson}));

      // Initial build
      await container.read(groupsProvider.future);
      expect(callCount, 1);

      // Create triggers refresh
      await container.read(groupsProvider.notifier).createGroup('New Group');
      expect(callCount, greaterThan(1));
    });

    test('joinGroup triggers refresh', () async {
      var callCount = 0;
      when(() => mockApi.getGroups()).thenAnswer((_) async {
        callCount++;
        return fakeResponse({
          'groups': [groupJson],
        });
      });
      when(() => mockApi.joinGroup(any()))
          .thenAnswer((_) async => fakeResponse({'group': groupJson}));

      await container.read(groupsProvider.future);
      expect(callCount, 1);

      await container.read(groupsProvider.notifier).joinGroup('ABC123');
      expect(callCount, greaterThan(1));
    });

    test('deleteGroup triggers refresh', () async {
      var callCount = 0;
      when(() => mockApi.getGroups()).thenAnswer((_) async {
        callCount++;
        return fakeResponse({
          'groups': [groupJson],
        });
      });
      when(() => mockApi.deleteGroup(any()))
          .thenAnswer((_) async => fakeResponse(null, statusCode: 204));

      await container.read(groupsProvider.future);
      expect(callCount, 1);

      await container.read(groupsProvider.notifier).deleteGroup('some-id');
      expect(callCount, greaterThan(1));
    });
  });

  group('groupsProvider error paths', () {
    test('createGroup propagates API error', () async {
      when(() => mockApi.getGroups()).thenAnswer(
          (_) async => fakeResponse({'groups': [groupJson]}));
      when(() => mockApi.createGroup(any()))
          .thenThrow(Exception('server error'));

      await container.read(groupsProvider.future);

      await expectLater(
        container.read(groupsProvider.notifier).createGroup('Test'),
        throwsA(isA<Exception>()),
      );
    });

    test('joinGroup propagates API error', () async {
      when(() => mockApi.getGroups()).thenAnswer(
          (_) async => fakeResponse({'groups': [groupJson]}));
      when(() => mockApi.joinGroup(any()))
          .thenThrow(Exception('invalid code'));

      await container.read(groupsProvider.future);

      await expectLater(
        container.read(groupsProvider.notifier).joinGroup('BAD'),
        throwsA(isA<Exception>()),
      );
    });

    test('deleteGroup propagates API error', () async {
      when(() => mockApi.getGroups()).thenAnswer(
          (_) async => fakeResponse({'groups': [groupJson]}));
      when(() => mockApi.deleteGroup(any()))
          .thenThrow(Exception('not found'));

      await container.read(groupsProvider.future);

      await expectLater(
        container.read(groupsProvider.notifier).deleteGroup('bad-id'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('groupMembersProvider', () {
    test('fetches and parses members', () async {
      when(() => mockApi.getMembers(any())).thenAnswer((_) async =>
          fakeResponse({
            'members': [groupMemberJson],
          }));

      final members =
          await container.read(groupMembersProvider('group-id').future);

      expect(members, hasLength(1));
      expect(members.first.displayName, 'Alice');
      expect(members.first.role, 'admin');
    });
  });
}
