import 'package:fence/models/app_location.dart';

class AppGeofence {
  final String identifier;
  final double latitude;
  final double longitude;
  final double radius;

  const AppGeofence({
    required this.identifier,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });
}

class AppGeofenceEvent {
  final String identifier;
  final String action; // 'entered' or 'exited'
  final AppLocation location;

  const AppGeofenceEvent({
    required this.identifier,
    required this.action,
    required this.location,
  });
}
