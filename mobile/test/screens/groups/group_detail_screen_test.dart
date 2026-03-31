import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/l10n/app_localizations.dart';
import 'package:fence/models/group.dart';
import 'package:fence/models/geofence.dart';
import 'package:fence/providers/groups_provider.dart';
import 'package:fence/providers/geofences_provider.dart';
import 'package:fence/services/api_client.dart';
import 'package:fence/screens/groups/group_detail_screen.dart';
import '../../helpers/mocks.dart';

const _testGroupId = 'test-group-id';

final _testMember = GroupMember(
  id: 'member-1',
  displayName: 'Alice',
  email: 'alice@example.com',
  role: 'admin',
  joinedAt: DateTime(2025),
);

final _testGeofence = Geofence(
  id: 'geo-1',
  name: 'Home',
  description: 'Our house',
  latitude: 37.7749,
  longitude: -122.4194,
  radiusMeters: 200,
  expiresAt: DateTime(2026),
  groupId: _testGroupId,
  insertedAt: DateTime(2025),
);

void main() {
  late MockApiClient mockApi;

  setUp(() {
    mockApi = MockApiClient();
  });

  Widget createApp({
    List<GroupMember>? members,
    List<Geofence>? geofences,
    bool membersLoading = false,
    bool geofencesLoading = false,
    String? membersError,
  }) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(mockApi),
        groupMembersProvider(_testGroupId).overrideWith((ref) {
          if (membersLoading) return Completer<List<GroupMember>>().future;
          if (membersError != null) throw Exception(membersError);
          return Future.value(members ?? []);
        }),
        geofencesProvider(_testGroupId).overrideWith((ref) {
          if (geofencesLoading) return Completer<List<Geofence>>().future;
          return Future.value(geofences ?? []);
        }),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GroupDetailScreen(groupId: _testGroupId),
      ),
    );
  }

  group('GroupDetailScreen', () {
    testWidgets('shows Members and Geofences section headings',
        (tester) async {
      await tester.pumpWidget(createApp(
        members: [_testMember],
        geofences: [_testGeofence],
      ));
      await tester.pump();

      expect(find.text('Members'), findsOneWidget);
      expect(find.text('Geofences'), findsOneWidget);
    });

    testWidgets('shows member display name and role', (tester) async {
      await tester.pumpWidget(createApp(members: [_testMember]));
      await tester.pump();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('admin'), findsOneWidget);
    });

    testWidgets('shows geofence name and radius', (tester) async {
      await tester.pumpWidget(createApp(geofences: [_testGeofence]));
      await tester.pump();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('200m radius'), findsOneWidget);
    });

    testWidgets('shows "No geofences yet" when empty', (tester) async {
      await tester.pumpWidget(createApp(geofences: []));
      await tester.pump();

      expect(find.text('No geofences yet'), findsOneWidget);
    });

    testWidgets('shows loading spinner when members loading',
        (tester) async {
      await tester.pumpWidget(createApp(membersLoading: true));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('shows Add Geofence FAB', (tester) async {
      await tester.pumpWidget(createApp());
      await tester.pump();

      expect(find.text('Add Geofence'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('invite button in app bar', (tester) async {
      await tester.pumpWidget(createApp());
      await tester.pump();

      expect(find.byTooltip('Invite'), findsOneWidget);
    });

    testWidgets('shows error state', (tester) async {
      await tester
          .pumpWidget(createApp(membersError: 'Network failure'));
      await tester.pump();

      expect(find.textContaining('Error'), findsOneWidget);
    });

    testWidgets('shows multiple members', (tester) async {
      final members = [
        _testMember,
        GroupMember(
          id: 'member-2',
          displayName: 'Bob',
          email: 'bob@example.com',
          role: 'member',
          joinedAt: DateTime(2025),
        ),
      ];
      await tester.pumpWidget(createApp(members: members));
      await tester.pump();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('admin'), findsOneWidget);
      expect(find.text('member'), findsOneWidget);
    });
  });
}
