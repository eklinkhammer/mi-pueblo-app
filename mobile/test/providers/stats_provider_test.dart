import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fence/providers/stats_provider.dart';
import 'package:fence/services/api_client.dart';
import '../helpers/mocks.dart';
import '../helpers/fakes.dart';

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

  group('statsProvider', () {
    test('fetches and parses stats', () async {
      when(() => mockApi.getStats()).thenAnswer((_) async => fakeResponse({
            'stats': [
              {
                'group_id': 'g1',
                'group_name': 'Family',
                'home_geofence_name': 'Home',
                'home_visit_count': 5,
                'housemates': <Map<String, dynamic>>[],
                'your_top_geofences': [
                  {'geofence_id': 'gf1', 'geofence_name': 'Work', 'visit_count': 3},
                ],
              }
            ]
          }));

      final stats = await container.read(statsProvider.future);

      expect(stats, hasLength(1));
      expect(stats.first.groupName, 'Family');
      expect(stats.first.homeVisitCount, 5);
      expect(stats.first.yourTopGeofences, hasLength(1));
    });

    test('handles empty stats list', () async {
      when(() => mockApi.getStats())
          .thenAnswer((_) async => fakeResponse({'stats': <Map<String, dynamic>>[]}));

      final stats = await container.read(statsProvider.future);

      expect(stats, isEmpty);
    });

    test('propagates API error', () async {
      when(() => mockApi.getStats()).thenThrow(Exception('network error'));

      expect(
        () => container.read(statsProvider.future),
        throwsA(isA<Exception>()),
      );
    });
  });
}
