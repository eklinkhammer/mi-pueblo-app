import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/services/api_client.dart';
import 'package:fence/services/location_service.dart';

final geofenceSyncServiceProvider = Provider<GeofenceSyncService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final backend = ref.watch(geolocationBackendProvider);
  return GeofenceSyncService(apiClient, backend);
});

class GeofenceSyncService {
  final ApiClient _apiClient;
  final GeolocationBackend _backend;
  bool _listening = false;
  bool _disposed = false;

  GeofenceSyncService(this._apiClient, this._backend);

  Future<void> syncGeofences() async {
    if (_disposed) return;
    try {
      final response = await _apiClient.getMyGeofences();
      final data = response.data!;
      final geofences = data['geofences'] as List<dynamic>;

      // Remove all existing geofences first
      await _backend.removeGeofences();

      if (geofences.isEmpty) return;

      // Add all server geofences as native geofences
      final nativeGeofences = geofences.map((g) {
        final map = g as Map<String, dynamic>;
        return bg.Geofence(
          identifier: map['id'] as String,
          latitude: (map['latitude'] as num).toDouble(),
          longitude: (map['longitude'] as num).toDouble(),
          radius: (map['radius_meters'] as num).toDouble(),
          notifyOnEntry: true,
          notifyOnExit: true,
        );
      }).toList();

      await _backend.addGeofences(nativeGeofences);
    } on Exception catch (_) {
      // Silently fail - will retry on next sync trigger
    }
  }

  void startListening() {
    if (_listening || _disposed) return;
    _listening = true;

    _backend.onGeofence(_handleGeofenceEvent);
  }

  Future<void> dispose() async {
    _disposed = true;
    _listening = false;
    await _backend.removeGeofences();
  }

  Future<void> _handleGeofenceEvent(bg.GeofenceEvent event) async {
    if (_disposed) return;
    final identifier = event.identifier;
    final action = event.action == 'ENTER' ? 'entered' : 'exited';
    final location = event.location;
    final coords = location.coords;
    final battery = location.battery;

    try {
      await _apiClient.reportGeofenceEvent({
        'geofence_id': identifier,
        'action': action,
        'latitude': coords.latitude,
        'longitude': coords.longitude,
        'accuracy': coords.accuracy,
        'altitude': coords.altitude,
        'speed': coords.speed,
        'bearing': coords.heading,
        'battery_level': battery.level,
      });
    } on Exception catch (_) {
      // Silently fail - periodic location checks are the safety net
    }
  }
}
