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

  /// Track currently registered native geofence IDs for delta sync.
  /// Since native_geofence doesn't expose getRegisteredGeofenceIds(),
  /// we maintain this set locally.
  final Set<String> _registeredIds = {};

  GeofenceSyncService(this._apiClient);

  Future<void> syncGeofences() async {
    if (_disposed) return;
    try {
      final response = await _apiClient.getMyGeofences();
      final data = response.data!;
      final geofences = data['geofences'] as List<dynamic>;

      final serverGeofences =
          geofences.map((g) => g as Map<String, dynamic>).toList();
      final serverIds = serverGeofences.map((g) => g['id'] as String).toSet();

      // Determine what needs to change
      final toRemove = _registeredIds.difference(serverIds);
      final toAdd = serverIds.difference(_registeredIds);

      // If nothing changed, skip re-registration
      if (toRemove.isEmpty && toAdd.isEmpty) return;

      // native_geofence only supports removeAll, so if we have removals
      // we must remove all and re-add the ones we want to keep.
      if (toRemove.isNotEmpty) {
        await NativeGeofenceManager.instance.removeAllGeofences();
        _registeredIds.clear();

        // Re-add all server geofences (since we had to remove all)
        for (final g in serverGeofences) {
          await _registerGeofence(g);
        }
      } else {
        // Only additions needed — no monitoring gap for existing geofences
        for (final g in serverGeofences) {
          if (toAdd.contains(g['id'] as String)) {
            await _registerGeofence(g);
          }
        }
      }
    } on Exception catch (_) {
      // Silently fail - will retry on next sync trigger
    }
  }

  Future<void> _registerGeofence(Map<String, dynamic> g) async {
    final id = g['id'] as String;
    try {
      final geofence = Geofence(
        id: id,
        location: Location(
          latitude: (g['latitude'] as num).toDouble(),
          longitude: (g['longitude'] as num).toDouble(),
        ),
        radiusMeters: (g['radius_meters'] as num).toDouble(),
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
      _registeredIds.add(id);
    } on Exception catch (_) {
      // Skip this geofence, will retry on next sync
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await NativeGeofenceManager.instance.removeAllGeofences();
      _registeredIds.clear();
    } on Exception catch (_) {
      // Best effort cleanup
    }
  }
}
