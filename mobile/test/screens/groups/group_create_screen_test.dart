import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fence/l10n/app_localizations.dart';
import 'package:fence/models/group.dart';
import 'package:fence/providers/groups_provider.dart';
import 'package:fence/screens/groups/group_create_screen.dart';

void main() {
  late _TrackingGroupsNotifier fakeNotifier;

  Widget createApp({bool shouldFail = false}) {
    fakeNotifier = _TrackingGroupsNotifier(shouldFail: shouldFail);
    final router = GoRouter(
      initialLocation: '/groups/create',
      routes: [
        GoRoute(
          path: '/groups/create',
          builder: (_, __) => const GroupCreateScreen(),
        ),
        GoRoute(
          path: '/groups/:id',
          builder: (_, __) => const Scaffold(body: Text('Detail')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        groupsProvider.overrideWith(() => fakeNotifier),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }

  group('GroupCreateScreen', () {
    testWidgets('renders Group Name field and Create Group button',
        (tester) async {
      await tester.pumpWidget(createApp());
      await tester.pumpAndSettle();

      expect(
          find.widgetWithText(TextField, 'Group Name'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Create Group'),
          findsOneWidget);
    });

    testWidgets('valid name triggers createGroup', (tester) async {
      await tester.pumpWidget(createApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Family');
      await tester.tap(find.widgetWithText(FilledButton, 'Create Group'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.createGroupCalled, isTrue);
      expect(fakeNotifier.lastGroupName, 'Family');
    });

    testWidgets('empty name does not trigger createGroup', (tester) async {
      await tester.pumpWidget(createApp());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Create Group'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.createGroupCalled, isFalse);
    });

    testWidgets('shows error SnackBar on failure', (tester) async {
      await tester.pumpWidget(createApp(shouldFail: true));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Bad Group');
      await tester.tap(find.widgetWithText(FilledButton, 'Create Group'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Failed'), findsOneWidget);
    });
  });
}

class _TrackingGroupsNotifier extends AsyncNotifier<List<Group>>
    implements GroupsNotifier {
  final bool shouldFail;
  bool createGroupCalled = false;
  String? lastGroupName;

  _TrackingGroupsNotifier({this.shouldFail = false});

  @override
  Future<List<Group>> build() async => [];

  @override
  Future<void> refresh() async {}

  @override
  Future<Group> createGroup(String name) async {
    createGroupCalled = true;
    lastGroupName = name;
    if (shouldFail) throw Exception('Server error');
    return Group(id: 'new-id', name: name, insertedAt: DateTime.now());
  }

  @override
  Future<Group> joinGroup(String inviteCode) async =>
      Group(id: '1', name: 'Test', insertedAt: DateTime.now());

  @override
  Future<void> deleteGroup(String id) async {}

  @override
  Future<void> leaveGroup(String groupId) async {}
}
