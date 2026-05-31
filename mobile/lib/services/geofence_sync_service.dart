import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:fence/services/api_client.dart';
import 'package:fence/services/headless_task.dart';

final geofenceSyncServiceProvider = Provider<GeofenceSyncService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return GeofenceSyncService(apiClient);
});

class GeofenceSyncService {
  final ApiClient _apiClient;
  bool _disposed = false;

  GeofenceSyncService(this._apiClient);

  Future<void> syncGeofences() async {
    if (_disposed) return;
    try {
      final response = await _apiClient.getMyGeofences();
      final data = response.data!;
      final geofences = data['geofences'] as List<dynamic>;

      // Remove all existing geofences first
      await NativeGeofenceManager.instance.removeAllGeofences();

      if (geofences.isEmpty) return;

      // Add all server geofences as native geofences
      for (final g in geofences) {
        final map = g as Map<String, dynamic>;
        final geofence = Geofence(
          id: map['id'] as String,
          location: Location(
            latitude: (map['latitude'] as num).toDouble(),
            longitude: (map['longitude'] as num).toDouble(),
          ),
          radiusMeters: (map['radius_meters'] as num).toDouble(),
          triggers: {GeofenceEvent.enter, GeofenceEvent.exit},
          androidSettings: const AndroidGeofenceSettings(
            initialTriggers: {GeofenceEvent.enter},
          ),
          iosSettings: const IosGeofenceSettings(
            initialTrigger: true,
          ),
        );
        await NativeGeofenceManager.instance
            .createGeofence(geofence, geofenceCallback);
      }
    } on Exception catch (_) {
      // Silently fail - will retry on next sync trigger
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await NativeGeofenceManager.instance.removeAllGeofences();
    } on Exception catch (_) {
      // Best effort cleanup
    }
  }
}
