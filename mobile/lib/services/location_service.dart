import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/config.dart';
import 'package:fence/models/app_location.dart';
import 'package:fence/services/api_client.dart';

enum PermissionStatus { granted, denied, notDetermined }

/// Abstraction over [bg.BackgroundGeolocation] static methods so that
/// [LocationService] can be unit-tested with a fake/mock backend.
abstract class GeolocationBackend {
  Future<int> requestPermission();
  Future<bg.State> ready(bg.Config config);
  Future<bg.State> start();
  Future<bg.State> stop();
  Future<bg.Location> getCurrentPosition(
      {Map<String, dynamic> extras = const {}});
  void onLocation(void Function(bg.Location) callback);
  void onMotionChange(void Function(bg.Location) callback);
  Future<void> addGeofences(List<bg.Geofence> geofences);
  Future<void> removeGeofences([List<String>? identifiers]);
  void onGeofence(void Function(bg.GeofenceEvent) callback);
}

/// Default implementation that delegates to the real plugin.
class BgGeolocationBackend implements GeolocationBackend {
  @override
  Future<int> requestPermission() =>
      bg.BackgroundGeolocation.requestPermission();

  @override
  Future<bg.State> ready(bg.Config config) =>
      bg.BackgroundGeolocation.ready(config);

  @override
  Future<bg.State> start() => bg.BackgroundGeolocation.start();

  @override
  Future<bg.State> stop() => bg.BackgroundGeolocation.stop();

  @override
  Future<bg.Location> getCurrentPosition(
          {Map<String, dynamic> extras = const {}}) =>
      bg.BackgroundGeolocation.getCurrentPosition(extras: extras);

  @override
  void onLocation(void Function(bg.Location) callback) =>
      bg.BackgroundGeolocation.onLocation(callback);

  @override
  void onMotionChange(void Function(bg.Location) callback) =>
      bg.BackgroundGeolocation.onMotionChange(callback);

  @override
  Future<void> addGeofences(List<bg.Geofence> geofences) =>
      bg.BackgroundGeolocation.addGeofences(geofences);

  @override
  Future<void> removeGeofences([List<String>? identifiers]) async {
    if (identifiers == null) {
      await bg.BackgroundGeolocation.removeGeofences();
    } else {
      for (final id in identifiers) {
        await bg.BackgroundGeolocation.removeGeofence(id);
      }
    }
  }

  @override
  void onGeofence(void Function(bg.GeofenceEvent) callback) =>
      bg.BackgroundGeolocation.onGeofence(callback);
}

final geolocationBackendProvider = Provider<GeolocationBackend>((ref) {
  return BgGeolocationBackend();
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

  LocationService(this._apiClient, [GeolocationBackend? backend])
      : _backend = backend ?? BgGeolocationBackend();

  Stream<AppLocation> get onLocation => _locationController.stream;

  Future<PermissionStatus> requestPermissions() async {
    final status = await _backend.requestPermission();
    if (status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_ALWAYS ||
        status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_WHEN_IN_USE) {
      return PermissionStatus.granted;
    }
    if (status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_DENIED) {
      return PermissionStatus.denied;
    }
    return PermissionStatus.notDetermined;
  }

  Future<void> _ensureConfigured() {
    _readyFuture ??= _configure();
    return _readyFuture!;
  }

  Future<void> _configure() async {
    _backend.onLocation(_onLocation);
    _backend.onMotionChange(_onMotionChange);

    await _backend.ready(bg.Config(
      desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
      distanceFilter: kDebugMode ? 10.0 : AppConfig.locationDistanceFilter.toDouble(),
      locationUpdateInterval: kDebugMode ? 30000 : AppConfig.locationIntervalMs,
      disableStopDetection: kDebugMode,
      debug: kDebugMode,
      stopOnTerminate: false,
      startOnBoot: true,
      enableHeadless: true,
      autoSync: false,
      foregroundService: true,
      backgroundPermissionRationale: bg.PermissionRationale(
        title: 'Allow Mi Pueblo to access your location in the background?',
        message: 'This app collects location data so you can share your location and arrival data with family members',
        positiveAction: 'Change to "Allow all the time"',
        negativeAction: 'Cancel',
      ),
      notification: bg.Notification(
        title: 'Mi Pueblo',
        text: 'Location sharing active',
      ),
    ));
  }

  void _onLocation(bg.Location location) {
    if (_disposed) return;
    final appLoc = _toAppLocation(location);
    _locationController.add(appLoc);
    _reportAppLocation(appLoc);
  }

  void _onMotionChange(bg.Location location) {
    if (_disposed) return;
    final appLoc = _toAppLocation(location);
    _locationController.add(appLoc);
    _reportAppLocation(appLoc);
  }

  AppLocation _toAppLocation(bg.Location location) {
    final coords = location.coords;
    final battery = location.battery;
    return AppLocation(
      latitude: coords.latitude,
      longitude: coords.longitude,
      accuracy: coords.accuracy,
      altitude: coords.altitude,
      speed: coords.speed,
      heading: coords.heading,
      batteryLevel: battery.level,
    );
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
      final location = await _backend.getCurrentPosition(
        extras: {},
      );
      return _toAppLocation(location);
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
    _locationController.close();
  }
}
