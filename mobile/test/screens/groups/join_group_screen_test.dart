import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fence/l10n/app_localizations.dart';
import 'package:fence/models/group.dart';
import 'package:fence/providers/groups_provider.dart';
import 'package:fence/screens/groups/join_group_screen.dart';

void main() {
  late _TrackingGroupsNotifier fakeNotifier;

  Widget createApp({bool shouldFail = false}) {
    fakeNotifier = _TrackingGroupsNotifier(shouldFail: shouldFail);
    final router = GoRouter(
      initialLocation: '/groups/join',
      routes: [
        GoRoute(
          path: '/groups/join',
          builder: (_, __) => const JoinGroupScreen(),
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

  group('JoinGroupScreen', () {
    testWidgets('renders Invite Code field and Join Group button',
        (tester) async {
      await tester.pumpWidget(createApp());
      await tester.pumpAndSettle();

      expect(
          find.widgetWithText(TextField, 'Invite Code'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Join Group'),
          findsOneWidget);
    });

    testWidgets('valid code triggers joinGroup', (tester) async {
      await tester.pumpWidget(createApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ABC123');
      await tester.tap(find.widgetWithText(FilledButton, 'Join Group'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.joinGroupCalled, isTrue);
      expect(fakeNotifier.lastInviteCode, 'ABC123');
    });

    testWidgets('empty code does not trigger joinGroup', (tester) async {
      await tester.pumpWidget(createApp());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Join Group'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.joinGroupCalled, isFalse);
    });

    testWidgets('shows error on failure', (tester) async {
      await tester.pumpWidget(createApp(shouldFail: true));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'BADCODE');
      await tester.tap(find.widgetWithText(FilledButton, 'Join Group'));
      await tester.pumpAndSettle();

      expect(
          find.text('Invalid or expired invite code'), findsOneWidget);
    });
  });
}

class _TrackingGroupsNotifier extends AsyncNotifier<List<Group>>
    implements GroupsNotifier {
  final bool shouldFail;
  bool joinGroupCalled = false;
  String? lastInviteCode;

  _TrackingGroupsNotifier({this.shouldFail = false});

  @override
  Future<List<Group>> build() async => [];

  @override
  Future<void> refresh() async {}

  @override
  Future<Group> createGroup(String name) async =>
      Group(id: '1', name: name, insertedAt: DateTime.now());

  @override
  Future<Group> joinGroup(String inviteCode) async {
    joinGroupCalled = true;
    lastInviteCode = inviteCode;
    if (shouldFail) throw Exception('Invalid code');
    return Group(id: 'joined-id', name: 'Test', insertedAt: DateTime.now());
  }

  @override
  Future<void> deleteGroup(String id) async {}
}
