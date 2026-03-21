import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fence/providers/locations_provider.dart';
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

  group('groupLocationsProvider', () {
    test('fetches and parses locations', () async {
      when(() => mockApi.getGroupLocations(any())).thenAnswer((_) async =>
          fakeResponse({
            'locations': [memberLocationJson],
          }));

      final locations =
          await container.read(groupLocationsProvider('group-id').future);

      expect(locations, hasLength(1));
      expect(locations.first.displayName, 'Alice');
      expect(locations.first.latitude, 37.7749);
    });

    test('handles empty list', () async {
      when(() => mockApi.getGroupLocations(any())).thenAnswer((_) async =>
          fakeResponse({'locations': <Map<String, dynamic>>[]}));

      final locations =
          await container.read(groupLocationsProvider('group-id').future);

      expect(locations, isEmpty);
    });

    test('propagates API error', () async {
      when(() => mockApi.getGroupLocations(any()))
          .thenThrow(Exception('network error'));

      expect(
        () => container.read(groupLocationsProvider('group-id').future),
        throwsA(isA<Exception>()),
      );
    });

    test('handles locations with all-null optional fields', () async {
      when(() => mockApi.getGroupLocations(any())).thenAnswer((_) async =>
          fakeResponse({
            'locations': [memberLocationNullsJson],
          }));

      final locations =
          await container.read(groupLocationsProvider('group-id').future);

      expect(locations, hasLength(1));
      expect(locations.first.displayName, 'Bob');
      expect(locations.first.latitude, isNull);
      expect(locations.first.longitude, isNull);
      expect(locations.first.accuracy, isNull);
      expect(locations.first.speed, isNull);
      expect(locations.first.batteryLevel, isNull);
    });
  });
}
