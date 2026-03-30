import 'package:flutter_test/flutter_test.dart';
import 'package:fence/models/app_location.dart';

void main() {
  group('AppLocation', () {
    test('constructs with all fields', () {
      const loc = AppLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        accuracy: 10.0,
        altitude: 50.0,
        speed: 1.5,
        heading: 90.0,
        batteryLevel: 0.85,
      );

      expect(loc.latitude, 37.7749);
      expect(loc.longitude, -122.4194);
      expect(loc.accuracy, 10.0);
      expect(loc.altitude, 50.0);
      expect(loc.speed, 1.5);
      expect(loc.heading, 90.0);
      expect(loc.batteryLevel, 0.85);
    });

    test('uses correct default values for optional fields', () {
      const loc = AppLocation(
        latitude: 0.0,
        longitude: 0.0,
      );

      expect(loc.accuracy, 0);
      expect(loc.altitude, 0);
      expect(loc.speed, 0);
      expect(loc.heading, 0);
      expect(loc.batteryLevel, isNull);
    });

    test('allows null batteryLevel', () {
      const loc = AppLocation(
        latitude: 1.0,
        longitude: 2.0,
        batteryLevel: null,
      );

      expect(loc.batteryLevel, isNull);
    });
  });
}
