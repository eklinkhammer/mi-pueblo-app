import 'package:fence/models/app_location.dart';

AppLocation fakeAppLocation({
  double latitude = 37.7749,
  double longitude = -122.4194,
  double accuracy = 10.0,
  double altitude = 0.0,
  double speed = 1.2,
  double heading = 90.0,
  double? batteryLevel = 0.85,
}) {
  return AppLocation(
    latitude: latitude,
    longitude: longitude,
    accuracy: accuracy,
    altitude: altitude,
    speed: speed,
    heading: heading,
    batteryLevel: batteryLevel,
  );
}
