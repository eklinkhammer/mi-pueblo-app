class AppLocation {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double altitude;
  final double speed;
  final double heading;
  final double? batteryLevel;

  const AppLocation({
    required this.latitude,
    required this.longitude,
    this.accuracy = 0,
    this.altitude = 0,
    this.speed = 0,
    this.heading = 0,
    this.batteryLevel,
  });
}
