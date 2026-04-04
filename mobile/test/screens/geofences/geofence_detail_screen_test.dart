import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fence/l10n/app_localizations.dart';
import 'package:fence/models/geofence.dart';
import 'package:fence/providers/auth_provider.dart';
import 'package:fence/providers/geofences_provider.dart';
import 'package:fence/services/api_client.dart';
import 'package:fence/screens/geofences/geofence_detail_screen.dart';
import '../../helpers/mocks.dart';
import '../../helpers/http_overrides.dart';


const _testGroupId = 'test-group-id';
const _testGeofenceId = 'geo-1';

final _testGeofence = Geofence(
  id: _testGeofenceId,
  name: 'Home',
  description: 'Our house',
  latitude: 37.7749,
  longitude: -122.4194,
  radiusMeters: 100,
  expiresAt: DateTime(2026),
  groupId: _testGroupId,
  insertedAt: DateTime(2025),
);

const _testSubscription = GeofenceSubscription(
  id: 'sub-1',
  geofenceId: _testGeofenceId,
  notifyOnEntry: true,
  notifyOnExit: false,
  blacklistedUserIds: <String>[],
  throttleSeconds: 300,
);

void main() {
  late MockApiClient mockApi;

  setUpAll(() {
    HttpOverrides.global = TestHttpOverrides();
  });

  tearDownAll(() {
    HttpOverrides.global = null;
  });

  setUp(() {
    mockApi = MockApiClient();
    when(() => mockApi.getAccessToken()).thenAnswer((_) async => null);
  });

  Widget createApp({
    List<Geofence>? geofences,
    GeofenceSubscription? subscription,
    bool geofencesLoading = false,
    String? geofencesError,
  }) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(mockApi),
        geofencesProvider(_testGroupId).overrideWith((ref) {
          if (geofencesLoading) return Completer<List<Geofence>>().future;
          if (geofencesError != null) throw Exception(geofencesError);
          return Future.value(geofences ?? []);
        }),
        geofenceSubscriptionProvider(_testGeofenceId).overrideWith((ref) {
          return Future.value(subscription);
        }),
        geofenceResidentsProvider(
          (groupId: _testGroupId, geofenceId: _testGeofenceId),
        ).overrideWith((ref) => Future.value(<Resident>[])),
        authProvider.overrideWith((ref) => AuthNotifier(mockApi, MockLocalNotificationService())),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GeofenceDetailScreen(
          groupId: _testGroupId,
          geofenceId: _testGeofenceId,
        ),
      ),
    );
  }

  group('GeofenceDetailScreen', () {
    testWidgets('shows "Geofence not found" when ID not in list',
        (tester) async {
      await tester.pumpWidget(createApp(geofences: []));
      await tester.pump();

      expect(find.text('Geofence not found'), findsOneWidget);
    });

    testWidgets('shows loading state', (tester) async {
      await tester.pumpWidget(createApp(geofencesLoading: true));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error state', (tester) async {
      await tester.pumpWidget(createApp(geofencesError: 'Network'));
      await tester.pump();

      expect(find.textContaining('Error'), findsOneWidget);
    });

    testWidgets('shows geofence name and radius', (tester) async {
      await tester.pumpWidget(createApp(
        geofences: [_testGeofence],
        subscription: _testSubscription,
      ));
      await tester.pump();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('100 meters'), findsOneWidget);
    });

    testWidgets('shows description when present', (tester) async {
      await tester.pumpWidget(createApp(
        geofences: [_testGeofence],
        subscription: _testSubscription,
      ));
      await tester.pump();

      expect(find.text('Our house'), findsOneWidget);
    });

    testWidgets('shows Notify on Entry and Exit switches', (tester) async {
      await tester.pumpWidget(createApp(
        geofences: [_testGeofence],
        subscription: _testSubscription,
      ));
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Notify on Entry'),
        200,
      );
      expect(find.text('Notify on Entry'), findsOneWidget);
      expect(find.text('Notify on Exit'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNWidgets(2));
    });

    testWidgets('shows Opt out tile', (tester) async {
      await tester.pumpWidget(createApp(
        geofences: [_testGeofence],
        subscription: _testSubscription,
      ));
      await tester.pump();

      // Scroll down to find the opt-out tile (it's below the map and switches)
      await tester.scrollUntilVisible(
        find.text('Opt out of this geofence'),
        200,
      );
      expect(find.text('Opt out of this geofence'), findsOneWidget);
    });

    testWidgets('delete button shows confirmation dialog', (tester) async {
      await tester.pumpWidget(createApp(
        geofences: [_testGeofence],
        subscription: _testSubscription,
      ));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();

      expect(find.text('Delete Geofence?'), findsOneWidget);
      expect(find.text('This action cannot be undone.'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('hides description when null', (tester) async {
      final noDescGeofence = Geofence(
        id: _testGeofenceId,
        name: 'Work',
        latitude: 37.0,
        longitude: -122.0,
        radiusMeters: 50,
        expiresAt: DateTime(2026),
        groupId: _testGroupId,
        insertedAt: DateTime(2025),
      );
      await tester.pumpWidget(createApp(
        geofences: [noDescGeofence],
        subscription: _testSubscription,
      ));
      await tester.pump();

      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Description'), findsNothing);
    });

    testWidgets('shows Notifications section heading', (tester) async {
      await tester.pumpWidget(createApp(
        geofences: [_testGeofence],
        subscription: _testSubscription,
      ));
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Notifications'),
        200,
      );
      expect(find.text('Notifications'), findsOneWidget);
    });
  });
}
