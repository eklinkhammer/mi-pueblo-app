import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:fence/config.dart';
import 'package:fence/models/app_geofence.dart';
import 'package:fence/models/app_location.dart';
import 'package:fence/services/api_client.dart';

enum AppPermissionStatus { granted, denied, notDetermined }

/// Abstraction over location services so that [LocationService] can be
/// unit-tested with a fake/mock backend.
abstract class GeolocationBackend {
  Future<AppPermissionStatus> requestPermission();
  Future<void> configure({
    required int distanceFilter,
    required int intervalMs,
    required bool debug,
  });
  Future<void> start();
  Future<void> stop();
  Future<AppLocation?> getCurrentPosition();
  Stream<AppLocation> get onLocation;
  Future<void> addGeofences(List<AppGeofence> geofences);
  Future<void> removeGeofences([List<String>? identifiers]);
  Stream<AppGeofenceEvent> get onGeofence;
}

/// Implementation using geolocator + flutter_foreground_task.
class GeolocatorForegroundBackend implements GeolocationBackend {
  final _locationController = StreamController<AppLocation>.broadcast();
  final _geofenceController = StreamController<AppGeofenceEvent>.broadcast();
  final _battery = Battery();
  StreamSubscription<geo.Position>? _positionSub;
  bool _configured = false;
  int _distanceFilter = 50;

  @override
  Future<AppPermissionStatus> requestPermission() async {
    // Request "when in use" first
    var status = await ph.Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      return status.isDenied
          ? AppPermissionStatus.denied
          : AppPermissionStatus.notDetermined;
    }

    // Then request "always" for background location
    status = await ph.Permission.locationAlways.request();
    if (status.isGranted || status.isLimited) {
      return AppPermissionStatus.granted;
    }
    // "when in use" alone is not sufficient for background location
    return AppPermissionStatus.denied;
  }

  @override
  Future<void> configure({
    required int distanceFilter,
    required int intervalMs,
    required bool debug,
  }) async {
    _distanceFilter = distanceFilter;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'fence_location_channel',
        channelName: 'Location Tracking',
        channelDescription: 'Shares your location with family members',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: false,
        eventAction: ForegroundTaskEventAction.repeat(intervalMs),
      ),
    );

    _configured = true;
  }

  @override
  Future<void> start() async {
    if (!_configured) return;

    // Start listening to the position stream.
    // flutter_foreground_task handles the foreground service, so we use plain
    // LocationSettings here to avoid a duplicate notification.
    await _positionSub?.cancel();

    _positionSub = geo.Geolocator.getPositionStream(
      locationSettings: geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: _distanceFilter,
      ),
    ).listen((position) async {
      final batteryLevel = await _getBatteryLevel();
      final appLoc = AppLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude,
        speed: position.speed,
        heading: position.heading,
        batteryLevel: batteryLevel,
      );
      _locationController.add(appLoc);
    });

    // Start the foreground task service
    final serviceRunning = await FlutterForegroundTask.isRunningService;
    if (!serviceRunning) {
      await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'Mi Pueblo',
        notificationText: 'Location sharing active',
        callback: _foregroundTaskCallback,
      );
    }
  }

  @override
  Future<void> stop() async {
    await _positionSub?.cancel();
    _positionSub = null;
    await FlutterForegroundTask.stopService();
  }

  @override
  Future<AppLocation?> getCurrentPosition() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
        ),
      );
      final batteryLevel = await _getBatteryLevel();
      return AppLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude,
        speed: position.speed,
        heading: position.heading,
        batteryLevel: batteryLevel,
      );
    } on Exception catch (_) {
      return null;
    }
  }

  @override
  Stream<AppLocation> get onLocation => _locationController.stream;

  @override
  Future<void> addGeofences(List<AppGeofence> geofences) async {
    // Delegated to GeofenceSyncService which uses native_geofence directly
  }

  @override
  Future<void> removeGeofences([List<String>? identifiers]) async {
    // Delegated to GeofenceSyncService which uses native_geofence directly
  }

  @override
  Stream<AppGeofenceEvent> get onGeofence => _geofenceController.stream;

  Future<double?> _getBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      if (level < 0) return null;
      return level / 100.0;
    } on Exception catch (_) {
      return null;
    }
  }

  void dispose() {
    _positionSub?.cancel();
    _locationController.close();
    _geofenceController.close();
  }
}

/// Top-level callback for flutter_foreground_task — required to be top-level.
@pragma('vm:entry-point')
void _foregroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}

/// TaskHandler that runs inside the foreground service isolate.
class LocationTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Nothing needed on start
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // The main location tracking is handled by Geolocator.getPositionStream()
    // in the main isolate. This handler keeps the foreground service alive.
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // Cleanup
  }

  @override
  void onReceiveData(Object data) {
    // Handle data from main isolate if needed
  }
}

final geolocationBackendProvider = Provider<GeolocationBackend>((ref) {
  return GeolocatorForegroundBackend();
});

final locationServiceProvider = Provider<LocationService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final backend = ref.watch(geolocationBackendProvider);
  return LocationService(apiClient, backend);
});

class LocationService {
  final ApiClient _apiClient;
  final GeolocationBackend _backend;
  Future<void>? _readyFuture;
  bool _disposed = false;
  final _locationController = StreamController<AppLocation>.broadcast();
  StreamSubscription<AppLocation>? _backendSub;

  LocationService(this._apiClient, [GeolocationBackend? backend])
      : _backend = backend ?? GeolocatorForegroundBackend();

  Stream<AppLocation> get onLocation => _locationController.stream;

  Future<AppPermissionStatus> requestPermissions() async {
    return _backend.requestPermission();
  }

  Future<void> _ensureConfigured() {
    _readyFuture ??= _configure();
    return _readyFuture!;
  }

  Future<void> _configure() async {
    _backendSub = _backend.onLocation.listen(_onLocation);

    await _backend.configure(
      distanceFilter: kDebugMode ? 10 : AppConfig.locationDistanceFilter,
      intervalMs: kDebugMode ? 30000 : AppConfig.locationIntervalMs,
      debug: kDebugMode,
    );
  }

  void _onLocation(AppLocation appLoc) {
    if (_disposed) return;
    _locationController.add(appLoc);
    _reportAppLocation(appLoc);
  }

  Future<void> _reportAppLocation(AppLocation loc) async {
    try {
      await _apiClient.reportLocation({
        'latitude': loc.latitude,
        'longitude': loc.longitude,
        'accuracy': loc.accuracy,
        'altitude': loc.altitude,
        'speed': loc.speed,
        'bearing': loc.heading,
        'battery_level': loc.batteryLevel,
      });
    } on Exception catch (_) {
      // Silently fail - will retry on next event
    }
  }

  Future<AppLocation?> getCurrentPosition() async {
    try {
      await _ensureConfigured();
      return await _backend.getCurrentPosition();
    } on Exception catch (_) {
      return null;
    }
  }

  Future<void> startTracking() async {
    await _ensureConfigured();
    await _backend.start();
  }

  Future<void> stopTracking() async {
    await _backend.stop();
  }

  void dispose() {
    _disposed = true;
    _backend.stop();
    _backendSub?.cancel();
    _locationController.close();
  }
}
