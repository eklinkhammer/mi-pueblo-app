import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:native_geofence/native_geofence.dart';
import 'package:fence/services/api_client.dart';

/// Top-level callback for native_geofence headless events.
/// Fires when a geofence is triggered, even when the app is killed.
@pragma('vm:entry-point')
Future<void> geofenceCallback(GeofenceCallbackParams params) async {
  WidgetsFlutterBinding.ensureInitialized();
  final apiClient = ApiClient();
  final battery = Battery();

  try {
    final position = await geo.Geolocator.getCurrentPosition(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );

    double? batteryLevel;
    try {
      batteryLevel = (await battery.batteryLevel) / 100.0;
    } on Exception catch (_) {}

    final geofences = params.geofences;
    for (final activeGeofence in geofences) {
      final action = params.event == GeofenceEvent.enter ? 'entered' : 'exited';

      await apiClient.reportGeofenceEvent({
        'geofence_id': activeGeofence.id,
        'action': action,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'speed': position.speed,
        'bearing': position.heading,
        'battery_level': batteryLevel,
        'source': 'geofence_event',
      });
    }
  } on Exception catch (_) {
    // Silently fail
  }
}
