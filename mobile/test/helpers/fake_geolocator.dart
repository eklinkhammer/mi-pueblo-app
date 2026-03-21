import 'dart:async';
import 'package:geolocator/geolocator.dart';

class FakeGeolocatorPlatform extends GeolocatorPlatform {
  bool serviceEnabled;
  LocationPermission permission;
  Position? position;
  StreamController<Position>? positionStreamController;

  FakeGeolocatorPlatform({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.position,
    this.positionStreamController,
  });

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    if (position == null) throw Exception('Position unavailable');
    return position!;
  }

  @override
  Stream<Position> getPositionStream({
    LocationSettings? locationSettings,
  }) {
    return positionStreamController?.stream ?? const Stream.empty();
  }
}

Position fakePosition({
  double latitude = 37.7749,
  double longitude = -122.4194,
  double accuracy = 10.0,
  double altitude = 0.0,
  double speed = 1.2,
  double heading = 90.0,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime(2025, 3, 15),
    accuracy: accuracy,
    altitude: altitude,
    altitudeAccuracy: 0.0,
    heading: heading,
    headingAccuracy: 0.0,
    speed: speed,
    speedAccuracy: 0.0,
  );
}
