import 'package:flutter_test/flutter_test.dart';
import 'package:fence/models/member_location.dart';
import '../helpers/test_data.dart';

void main() {
  group('MemberLocation.fromJson', () {
    test('parses all fields correctly', () {
      final loc = MemberLocation.fromJson(
          Map<String, dynamic>.from(memberLocationJson));

      expect(loc.userId, '550e8400-e29b-41d4-a716-446655440000');
      expect(loc.displayName, 'Alice');
      expect(loc.latitude, 37.7749);
      expect(loc.longitude, -122.4194);
      expect(loc.accuracy, 10.5);
      expect(loc.speed, 1.2);
      expect(loc.batteryLevel, 0.85);
      expect(loc.updatedAt, DateTime.utc(2025, 3, 15, 14, 30));
    });

    test('handles null optional fields', () {
      final loc = MemberLocation.fromJson(
          Map<String, dynamic>.from(memberLocationNullsJson));

      expect(loc.displayName, 'Bob');
      expect(loc.latitude, isNull);
      expect(loc.longitude, isNull);
      expect(loc.accuracy, isNull);
      expect(loc.speed, isNull);
      expect(loc.batteryLevel, isNull);
    });

    test('coerces int to double for numeric fields', () {
      final json = {
        'user_id': 'uid',
        'display_name': 'Test',
        'latitude': 37,
        'longitude': -122,
        'accuracy': 10,
        'speed': 1,
        'battery_level': 1,
        'updated_at': '2025-03-15T14:30:00Z',
      };

      final loc = MemberLocation.fromJson(json);
      expect(loc.latitude, isA<double>());
      expect(loc.longitude, isA<double>());
      expect(loc.accuracy, isA<double>());
      expect(loc.speed, isA<double>());
      expect(loc.batteryLevel, isA<double>());
    });
  });
}
