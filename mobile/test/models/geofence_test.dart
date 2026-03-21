import 'package:flutter_test/flutter_test.dart';
import 'package:fence/models/geofence.dart';
import '../helpers/test_data.dart';

void main() {
  group('Geofence.fromJson', () {
    test('parses all fields correctly', () {
      final g = Geofence.fromJson(Map<String, dynamic>.from(geofenceJson));

      expect(g.id, '770e8400-e29b-41d4-a716-446655440002');
      expect(g.name, 'Home');
      expect(g.description, 'Our house');
      expect(g.latitude, 37.7749);
      expect(g.longitude, -122.4194);
      expect(g.radiusMeters, 100.0);
      expect(g.expiresAt, DateTime.utc(2025, 12, 31, 23, 59, 59));
      expect(g.groupId, '660e8400-e29b-41d4-a716-446655440001');
    });

    test('handles null description', () {
      final g = Geofence.fromJson(
          Map<String, dynamic>.from(geofenceJsonNullDescription));

      expect(g.description, isNull);
    });

    test('coerces int to double for coordinates and radius', () {
      final g = Geofence.fromJson(
          Map<String, dynamic>.from(geofenceJsonNullDescription));

      expect(g.latitude, 37.0);
      expect(g.longitude, -122.0);
      expect(g.radiusMeters, 50.0);
      expect(g.latitude, isA<double>());
      expect(g.longitude, isA<double>());
      expect(g.radiusMeters, isA<double>());
    });
  });

  group('GeofenceSubscription.fromJson', () {
    test('parses with empty blacklist', () {
      final sub = GeofenceSubscription.fromJson(
          Map<String, dynamic>.from(subscriptionJson));

      expect(sub.id, '880e8400-e29b-41d4-a716-446655440003');
      expect(sub.geofenceId, '770e8400-e29b-41d4-a716-446655440002');
      expect(sub.notifyOnEntry, isTrue);
      expect(sub.notifyOnExit, isFalse);
      expect(sub.blacklistedUserIds, isEmpty);
      expect(sub.throttleSeconds, 300);
    });

    test('parses with populated blacklist', () {
      final sub = GeofenceSubscription.fromJson(
          Map<String, dynamic>.from(subscriptionWithBlacklistJson));

      expect(sub.blacklistedUserIds, hasLength(2));
      expect(sub.blacklistedUserIds,
          contains('550e8400-e29b-41d4-a716-446655440000'));
      expect(sub.notifyOnExit, isTrue);
      expect(sub.throttleSeconds, 600);
    });
  });
}
