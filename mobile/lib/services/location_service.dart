import 'dart:async';
import 'dart:io' show Platform;
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
  int _intervalMs = 300000;
  Timer? _watchdog;
  Timer? _adaptiveTimer;
  double _lastSpeed = 0.0;
  double _lastBatteryLevel = 1.0;
  int _currentDistanceFilter = 50;

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
    _intervalMs = intervalMs;

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

    _currentDistanceFilter = _distanceFilter;
    await _startPositionStream();

    // Listen for heartbeat data sent from the foreground task isolate
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);

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

    _startAdaptiveTimer();
  }

  void _onTaskData(Object data) {
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final appLoc = AppLocation(
        latitude: map['latitude'] as double,
        longitude: map['longitude'] as double,
        accuracy: map['accuracy'] as double,
        altitude: map['altitude'] as double,
        speed: map['speed'] as double,
        heading: map['heading'] as double,
        batteryLevel: map['batteryLevel'] as double?,
      );
      _locationController.add(appLoc);
      _resetWatchdog();
    }
  }

  Future<void> _startPositionStream() async {
    await _positionSub?.cancel();
    _watchdog?.cancel();

    // Use platform-specific settings for reliable background delivery.
    // flutter_foreground_task handles the foreground service, so we omit
    // foregroundNotificationConfig to avoid a duplicate notification.
    final geo.LocationSettings settings;
    if (Platform.isAndroid) {
      settings = geo.AndroidSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: _currentDistanceFilter,
        intervalDuration: Duration(milliseconds: _intervalMs),
      );
    } else {
      settings = geo.AppleSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: _currentDistanceFilter,
        activityType: geo.ActivityType.other,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }

    _positionSub = geo.Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((position) async {
      _resetWatchdog();
      _lastSpeed = position.speed;
      final batteryLevel = await _getBatteryLevel();
      if (batteryLevel != null) _lastBatteryLevel = batteryLevel;
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
    }, onError: (Object error) {
      debugPrint('LocationService: position stream error: $error');
      // Restart after a brief delay to avoid tight loop
      Future.delayed(const Duration(seconds: 5), _startPositionStream);
    });

    _resetWatchdog();
  }

  /// Restarts the position stream if it silently stalls.
  void _resetWatchdog() {
    _watchdog?.cancel();
    const timeout = kDebugMode
        ? Duration(minutes: 2)
        : AppConfig.locationWatchdogTimeout;
    _watchdog = Timer(timeout, () {
      debugPrint('LocationService: watchdog fired — restarting position stream');
      _startPositionStream();
    });
  }

  void _startAdaptiveTimer() {
    _adaptiveTimer?.cancel();
    _adaptiveTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _maybeAdaptTracking(),
    );
  }

  void _maybeAdaptTracking() {
    int idealFilter;

    if (_lastBatteryLevel < AppConfig.batteryCriticalThreshold) {
      idealFilter = AppConfig.distanceFilterCritical;
    } else if (_lastBatteryLevel < AppConfig.batteryLowThreshold) {
      idealFilter = AppConfig.distanceFilterLowBattery;
    } else if (_lastSpeed < AppConfig.stationarySpeedThreshold) {
      // Stationary — use default filter (less frequent updates)
      idealFilter = _distanceFilter;
    } else {
      // Moving with good battery — tighter filter
      idealFilter = AppConfig.distanceFilterMoving;
    }

    if (idealFilter != _currentDistanceFilter) {
      debugPrint(
        'LocationService: adapting distance filter '
        '$_currentDistanceFilter -> $idealFilter '
        '(battery=${(_lastBatteryLevel * 100).toInt()}%, speed=${_lastSpeed.toStringAsFixed(1)}m/s)',
      );
      _currentDistanceFilter = idealFilter;
      _startPositionStream();
    }
  }

  @override
  Future<void> stop() async {
    _adaptiveTimer?.cancel();
    _adaptiveTimer = null;
    _watchdog?.cancel();
    _watchdog = null;
    await _positionSub?.cancel();
    _positionSub = null;
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
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
    _adaptiveTimer?.cancel();
    _watchdog?.cancel();
    _positionSub?.cancel();
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
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
///
/// `onRepeatEvent()` acts as a heartbeat: it polls the current position and
/// sends it back to the main isolate so location is reported even when the
/// position stream stalls or the user is stationary.
class LocationTaskHandler extends TaskHandler {
  final _battery = Battery();

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Nothing needed on start
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    try {
      // Check battery level first — skip heartbeat poll if critical
      double? batteryLevel;
      try {
        final level = await _battery.batteryLevel;
        if (level >= 0) batteryLevel = level / 100.0;
      } on Exception catch (_) {
        // Ignore battery errors
      }

      if (batteryLevel != null &&
          batteryLevel < AppConfig.batteryCriticalThreshold) {
        debugPrint(
            'LocationTaskHandler: skipping heartbeat (battery ${(batteryLevel * 100).toInt()}%)');
        return;
      }

      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
        ),
      );

      FlutterForegroundTask.sendDataToMain({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'speed': position.speed,
        'heading': position.heading,
        'batteryLevel': batteryLevel,
      });
    } on Exception catch (e) {
      debugPrint('LocationTaskHandler heartbeat failed: $e');
    }
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
