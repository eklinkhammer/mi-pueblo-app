import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/config.dart';
import 'package:fence/services/api_client.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return LocationService(apiClient);
});

class LocationService {
  final ApiClient _apiClient;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _periodicTimer;

  LocationService(this._apiClient);

  Future<bool> requestPermissions() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );
    } on Exception catch (_) {
      return null;
    }
  }

  void startTracking() {
    // Periodic location reporting
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(AppConfig.locationInterval, (_) async {
      await _reportCurrentLocation();
    });

    // Also report on significant movement
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: AppConfig.locationDistanceFilter,
      ),
    ).listen(_reportPosition);

    // Report initial position
    unawaited(_reportCurrentLocation());
  }

  void stopTracking() {
    _periodicTimer?.cancel();
    _positionSubscription?.cancel();
  }

  Future<void> _reportCurrentLocation() async {
    final position = await getCurrentPosition();
    if (position != null) {
      await _reportPosition(position);
    }
  }

  Future<void> _reportPosition(Position position) async {
    try {
      await _apiClient.reportLocation({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'speed': position.speed,
        'bearing': position.heading,
      });
    } on Exception catch (_) {
      // Silently fail - will retry on next interval
    }
  }

  void dispose() {
    stopTracking();
  }
}
