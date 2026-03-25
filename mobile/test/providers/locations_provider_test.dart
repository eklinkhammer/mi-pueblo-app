import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fence/providers/locations_provider.dart';
import 'package:fence/services/api_client.dart';
import 'package:fence/services/websocket_service.dart';
import '../helpers/mocks.dart';
import '../helpers/fakes.dart';
import '../helpers/test_data.dart';

void main() {
  late MockApiClient mockApi;
  late MockWebSocketService mockWs;
  late ProviderContainer container;

  setUp(() {
    mockApi = MockApiClient();
    mockWs = MockWebSocketService();
    when(() => mockWs.messages)
        .thenAnswer((_) => const Stream<Map<String, dynamic>>.empty());
    container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(mockApi),
        websocketServiceProvider.overrideWithValue(mockWs),
      ],
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

    test('applies WebSocket location updates', () async {
      final wsController =
          StreamController<Map<String, dynamic>>.broadcast();
      when(() => mockWs.messages).thenAnswer((_) => wsController.stream);
      when(() => mockApi.getGroupLocations(any())).thenAnswer((_) async =>
          fakeResponse({
            'locations': [memberLocationJson],
          }));

      // Re-create container so the new stream mock is picked up
      container.dispose();
      container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          websocketServiceProvider.overrideWithValue(mockWs),
        ],
      );

      final locations =
          await container.read(groupLocationsProvider('group-id').future);
      expect(locations.first.latitude, 37.7749);

      // Simulate WebSocket location update
      wsController.add({
        'topic': 'group:group-id',
        'event': 'location:updated',
        'payload': {
          'user_id': '550e8400-e29b-41d4-a716-446655440000',
          'display_name': 'Alice',
          'latitude': 38.0,
          'longitude': -123.0,
          'accuracy': 5.0,
          'speed': 0.0,
          'battery_level': 0.9,
          'updated_at': '2025-03-15T14:35:00Z',
        },
      });

      // Allow async processing
      await Future<void>.delayed(Duration.zero);

      final updated = container.read(groupLocationsProvider('group-id'));
      expect(updated.valueOrNull?.first.latitude, 38.0);

      await wsController.close();
    });
  });
}
