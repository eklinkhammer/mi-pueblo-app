import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fence/main.dart';
import 'package:fence/models/app_location.dart';
import 'package:fence/services/location_service.dart';

/// Pumps the full app with optional Riverpod overrides.
Future<void> pumpApp(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const FenceApp(),
    ),
  );
  // Allow async initialization (auth check, etc.)
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

/// A controllable fake location service for integration tests.
/// Avoids needing real device location or native mock APIs.
/// Not a subclass of LocationService — use via Riverpod provider override.
class FakeLocationService {
  double latitude;
  double longitude;
  double accuracy;
  final _locationController = StreamController<AppLocation>.broadcast();

  FakeLocationService({
    this.latitude = 37.7749,
    this.longitude = -122.4194,
    this.accuracy = 10.0,
  });

  Stream<AppLocation> get onLocation => _locationController.stream;

  void setPosition(double lat, double lng, {double acc = 10.0}) {
    latitude = lat;
    longitude = lng;
    accuracy = acc;
  }

  Future<AppPermissionStatus> requestPermissions() async =>
      AppPermissionStatus.granted;
  Future<void> startTracking() async {}
  Future<void> stopTracking() async {}
  void dispose() => _locationController.close();
}

/// Generates a unique email for test isolation.
String uniqueTestEmail() =>
    'test_${DateTime.now().millisecondsSinceEpoch}_${UniqueKey().hashCode}@example.com';
