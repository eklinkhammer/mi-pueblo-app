import 'package:flutter_test/flutter_test.dart';
import 'package:fence/models/geofence_event.dart';
import '../helpers/test_data.dart';

void main() {
  group('GeofenceEvent.fromJson', () {
    test('parses all fields correctly', () {
      final event =
          GeofenceEvent.fromJson(Map<String, dynamic>.from(geofenceEventJson));

      expect(event.id, '880e8400-e29b-41d4-a716-446655440010');
      expect(event.event, 'entered');
      expect(event.geofenceId, '770e8400-e29b-41d4-a716-446655440002');
      expect(event.geofenceName, 'Home');
      expect(event.insertedAt, DateTime.utc(2025, 6, 15, 14, 30));
    });

    test('parses ISO8601 DateTime with milliseconds', () {
      final json = Map<String, dynamic>.from(geofenceEventJson);
      json['inserted_at'] = '2025-06-15T20:45:30.123Z';

      final event = GeofenceEvent.fromJson(json);
      expect(event.insertedAt, DateTime.utc(2025, 6, 15, 20, 45, 30, 123));
    });
  });
}
