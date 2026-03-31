import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/l10n/app_localizations.dart';
import 'package:fence/models/group.dart';
import 'package:fence/providers/groups_provider.dart';
import 'package:fence/screens/groups/group_list_screen.dart';

void main() {
  Widget createApp({required AsyncValue<List<Group>> groupsState}) {
    return ProviderScope(
      overrides: [
        groupsProvider.overrideWith(() => _FakeGroupsNotifier(groupsState)),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GroupListScreen(),
      ),
    );
  }

  group('GroupListScreen', () {
    testWidgets('shows spinner when loading', (tester) async {
      await tester.pumpWidget(
          createApp(groupsState: const AsyncValue.loading()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty state with buttons when no groups',
        (tester) async {
      await tester
          .pumpWidget(createApp(groupsState: const AsyncValue.data([])));

      expect(find.text('No groups yet'), findsOneWidget);
      expect(find.text('Create a Group'), findsOneWidget);
      expect(find.text('Join with Invite Code'), findsOneWidget);
    });

    testWidgets('shows group names when data is present', (tester) async {
      final groups = [
        Group(
          id: '1',
          name: 'Family',
          insertedAt: DateTime(2025),
        ),
        Group(
          id: '2',
          name: 'Friends',
          insertedAt: DateTime(2025),
        ),
      ];

      await tester
          .pumpWidget(createApp(groupsState: AsyncValue.data(groups)));

      expect(find.text('Family'), findsOneWidget);
      expect(find.text('Friends'), findsOneWidget);
    });

    testWidgets('shows error message on error', (tester) async {
      await tester.pumpWidget(createApp(
        groupsState:
            AsyncValue.error('Network error', StackTrace.current),
      ));

      expect(find.textContaining('Error:'), findsOneWidget);
    });
  });
}

class _FakeGroupsNotifier extends AsyncNotifier<List<Group>>
    implements GroupsNotifier {
  final AsyncValue<List<Group>> _initialState;

  _FakeGroupsNotifier(this._initialState);

  @override
  Future<List<Group>> build() async {
    state = _initialState;
    return _initialState.valueOrNull ?? [];
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<Group> createGroup(String name) async =>
      Group(id: '1', name: name, insertedAt: DateTime.now());

  @override
  Future<Group> joinGroup(String inviteCode) async =>
      Group(id: '1', name: 'Test', insertedAt: DateTime.now());

  @override
  Future<void> deleteGroup(String id) async {}
}
