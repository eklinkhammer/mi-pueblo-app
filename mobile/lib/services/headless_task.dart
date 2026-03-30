import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'package:fence/services/api_client.dart';

@pragma('vm:entry-point')
Future<void> headlessTask(bg.HeadlessEvent headlessEvent) async {
  final event = headlessEvent.event;
  final apiClient = ApiClient();

  if (event is bg.Location) {
    try {
      final coords = event.coords;
      final battery = event.battery;
      await apiClient.reportLocation({
        'latitude': coords.latitude,
        'longitude': coords.longitude,
        'accuracy': coords.accuracy,
        'altitude': coords.altitude,
        'speed': coords.speed,
        'bearing': coords.heading,
        'battery_level': battery.level,
      });
    } on Exception catch (_) {
      // Silently fail
    }
  } else if (event is bg.GeofenceEvent) {
    try {
      final location = event.location;
      final coords = location.coords;
      final battery = location.battery;
      await apiClient.reportGeofenceEvent({
        'geofence_id': event.identifier,
        'action': event.action == 'ENTER' ? 'entered' : 'exited',
        'latitude': coords.latitude,
        'longitude': coords.longitude,
        'accuracy': coords.accuracy,
        'altitude': coords.altitude,
        'speed': coords.speed,
        'bearing': coords.heading,
        'battery_level': battery.level,
      });
    } on Exception catch (_) {
      // Silently fail
    }
  }
}
