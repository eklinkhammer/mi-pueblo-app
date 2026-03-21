import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fence/providers/geofences_provider.dart';
import 'package:fence/services/api_client.dart';
import '../helpers/mocks.dart';
import '../helpers/fakes.dart';
import '../helpers/test_data.dart';

void main() {
  late MockApiClient mockApi;
  late ProviderContainer container;

  setUp(() {
    mockApi = MockApiClient();
    container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(mockApi)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('geofencesProvider', () {
    test('fetches and parses geofences', () async {
      when(() => mockApi.getGeofences(any())).thenAnswer((_) async =>
          fakeResponse({
            'geofences': [geofenceJson],
          }));

      final geofences =
          await container.read(geofencesProvider('group-id').future);

      expect(geofences, hasLength(1));
      expect(geofences.first.name, 'Home');
      expect(geofences.first.latitude, 37.7749);
    });

    test('handles empty list', () async {
      when(() => mockApi.getGeofences(any())).thenAnswer((_) async =>
          fakeResponse({'geofences': <Map<String, dynamic>>[]}));

      final geofences =
          await container.read(geofencesProvider('group-id').future);

      expect(geofences, isEmpty);
    });
  });

  group('geofenceSubscriptionProvider', () {
    test('returns subscription when present', () async {
      when(() => mockApi.getSubscription(any())).thenAnswer(
          (_) async => fakeResponse({'subscription': subscriptionJson}));

      final sub = await container
          .read(geofenceSubscriptionProvider('geofence-id').future);

      expect(sub, isNotNull);
      expect(sub!.notifyOnEntry, isTrue);
      expect(sub.notifyOnExit, isFalse);
    });

    test('returns null when no subscription', () async {
      when(() => mockApi.getSubscription(any())).thenAnswer(
          (_) async => fakeResponse({'subscription': null}));

      final sub = await container
          .read(geofenceSubscriptionProvider('geofence-id').future);

      expect(sub, isNull);
    });
  });
}
