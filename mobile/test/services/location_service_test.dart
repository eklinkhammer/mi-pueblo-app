import 'dart:async';

import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fence/services/location_service.dart';
import '../helpers/fakes.dart';
import '../helpers/mocks.dart';

// ---------------------------------------------------------------------------
// Mock / Fake helpers
// ---------------------------------------------------------------------------

class MockGeolocationBackend extends Mock implements GeolocationBackend {}

/// Build a [bg.Location] from a simple map.  The real constructor parses a
/// native payload, so we supply the same shape it expects.
bg.Location fakeBgLocation({
  double latitude = 37.7749,
  double longitude = -122.4194,
  double accuracy = 10.0,
  double altitude = 50.0,
  double speed = 1.5,
  double heading = 90.0,
  double batteryLevel = 0.85,
  bool isCharging = false,
}) {
  return bg.Location({
    'coords': {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': altitude,
      'speed': speed,
      'heading': heading,
      'heading_accuracy': 5.0,
      'speed_accuracy': 1.0,
      'altitude_accuracy': 3.0,
      'ellipsoidal_altitude': altitude,
    },
    'battery': {
      'level': batteryLevel,
      'is_charging': isCharging,
    },
    'activity': {
      'type': 'unknown',
      'confidence': 100,
    },
    'timestamp': DateTime.now().toIso8601String(),
    'age': 0,
    'is_moving': speed > 0,
    'uuid': 'test-uuid',
    'odometer': 0.0,
  });
}

// Fallback values for mocktail matchers.
class _FakeBgConfig extends Fake implements bg.Config {}

class _FakeBgState extends Fake implements bg.State {}

void main() {
  late MockGeolocationBackend backend;
  late MockApiClient apiClient;
  late LocationService service;

  setUpAll(() {
    registerFallbackValue(_FakeBgConfig());
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    backend = MockGeolocationBackend();
    apiClient = MockApiClient();
    service = LocationService(apiClient, backend);

    // Default stubs — individual tests can override.
    when(() => backend.ready(any())).thenAnswer((_) async => _FakeBgState());
    when(() => backend.start()).thenAnswer((_) async => _FakeBgState());
    when(() => backend.stop()).thenAnswer((_) async => _FakeBgState());
    when(() => backend.onLocation(any())).thenReturn(null);
    when(() => backend.onMotionChange(any())).thenReturn(null);
    when(() => apiClient.reportLocation(any()))
        .thenAnswer((_) async => fakeResponse({'status': 'ok'}));
  });

  tearDown(() {
    service.dispose();
  });

  // -----------------------------------------------------------------------
  // requestPermissions
  // -----------------------------------------------------------------------
  group('requestPermissions', () {
    test('returns granted for AUTHORIZATION_STATUS_ALWAYS', () async {
      when(() => backend.requestPermission()).thenAnswer(
          (_) async => bg.ProviderChangeEvent.AUTHORIZATION_STATUS_ALWAYS);

      expect(await service.requestPermissions(), PermissionStatus.granted);
    });

    test('returns granted for AUTHORIZATION_STATUS_WHEN_IN_USE', () async {
      when(() => backend.requestPermission()).thenAnswer((_) async =>
          bg.ProviderChangeEvent.AUTHORIZATION_STATUS_WHEN_IN_USE);

      expect(await service.requestPermissions(), PermissionStatus.granted);
    });

    test('returns denied for AUTHORIZATION_STATUS_DENIED', () async {
      when(() => backend.requestPermission()).thenAnswer(
          (_) async => bg.ProviderChangeEvent.AUTHORIZATION_STATUS_DENIED);

      expect(await service.requestPermissions(), PermissionStatus.denied);
    });

    test('returns notDetermined for AUTHORIZATION_STATUS_NOT_DETERMINED',
        () async {
      when(() => backend.requestPermission()).thenAnswer((_) async =>
          bg.ProviderChangeEvent.AUTHORIZATION_STATUS_NOT_DETERMINED);

      expect(
          await service.requestPermissions(), PermissionStatus.notDetermined);
    });
  });

  // -----------------------------------------------------------------------
  // getCurrentPosition
  // -----------------------------------------------------------------------
  group('getCurrentPosition', () {
    test('returns AppLocation with correct field mapping', () async {
      final loc = fakeBgLocation(
        latitude: 40.0,
        longitude: -74.0,
        accuracy: 5.0,
        altitude: 100.0,
        speed: 3.0,
        heading: 180.0,
        batteryLevel: 0.6,
      );
      when(() => backend.getCurrentPosition(extras: any(named: 'extras')))
          .thenAnswer((_) async => loc);

      final result = await service.getCurrentPosition();

      expect(result, isNotNull);
      expect(result!.latitude, 40.0);
      expect(result.longitude, -74.0);
      expect(result.accuracy, 5.0);
      expect(result.altitude, 100.0);
      expect(result.speed, 3.0);
      expect(result.heading, 180.0);
      expect(result.batteryLevel, 0.6);
    });

    test('returns null on error', () async {
      when(() => backend.getCurrentPosition(extras: any(named: 'extras')))
          .thenThrow(Exception('GPS unavailable'));

      expect(await service.getCurrentPosition(), isNull);
    });
  });

  // -----------------------------------------------------------------------
  // startTracking / stopTracking
  // -----------------------------------------------------------------------
  group('startTracking', () {
    test('calls _ensureConfigured then start', () async {
      await service.startTracking();

      verify(() => backend.ready(any())).called(1);
      verify(() => backend.start()).called(1);
    });

    test('_ensureConfigured is idempotent — ready called only once', () async {
      await service.startTracking();
      await service.startTracking();

      verify(() => backend.ready(any())).called(1);
      verify(() => backend.start()).called(2);
    });
  });

  group('stopTracking', () {
    test('calls backend.stop()', () async {
      await service.stopTracking();

      verify(() => backend.stop()).called(1);
    });
  });

  // -----------------------------------------------------------------------
  // Location callbacks → stream + API report
  // -----------------------------------------------------------------------
  group('location callbacks', () {
    late void Function(bg.Location) capturedOnLocation;
    late void Function(bg.Location) capturedOnMotionChange;

    setUp(() async {
      // Capture the callbacks registered during _ensureConfigured.
      when(() => backend.onLocation(any())).thenAnswer((invocation) {
        capturedOnLocation =
            invocation.positionalArguments[0] as void Function(bg.Location);
      });
      when(() => backend.onMotionChange(any())).thenAnswer((invocation) {
        capturedOnMotionChange =
            invocation.positionalArguments[0] as void Function(bg.Location);
      });

      // Trigger configuration.
      await service.startTracking();
    });

    test('onLocation callback emits to stream and reports to API', () async {
      final loc = fakeBgLocation(latitude: 51.5, longitude: -0.1);

      final future = service.onLocation.first;
      capturedOnLocation(loc);
      final emitted = await future;

      expect(emitted.latitude, 51.5);
      expect(emitted.longitude, -0.1);

      // Give the async _reportAppLocation a tick to complete.
      await Future<void>.delayed(Duration.zero);
      verify(() => apiClient.reportLocation(any())).called(1);
    });

    test('onMotionChange callback emits to stream and reports to API',
        () async {
      final loc = fakeBgLocation(latitude: 48.8, longitude: 2.3);

      final future = service.onLocation.first;
      capturedOnMotionChange(loc);
      final emitted = await future;

      expect(emitted.latitude, 48.8);
      expect(emitted.longitude, 2.3);

      await Future<void>.delayed(Duration.zero);
      verify(() => apiClient.reportLocation(any())).called(1);
    });

    test('reportAppLocation sends correct payload shape', () async {
      final loc = fakeBgLocation(
        latitude: 35.0,
        longitude: 139.0,
        accuracy: 8.0,
        altitude: 20.0,
        speed: 2.0,
        heading: 45.0,
        batteryLevel: 0.9,
      );

      capturedOnLocation(loc);
      await Future<void>.delayed(Duration.zero);

      final captured =
          verify(() => apiClient.reportLocation(captureAny())).captured;
      final payload = captured.first as Map<String, dynamic>;

      expect(payload['latitude'], 35.0);
      expect(payload['longitude'], 139.0);
      expect(payload['accuracy'], 8.0);
      expect(payload['altitude'], 20.0);
      expect(payload['speed'], 2.0);
      expect(payload['bearing'], 45.0);
      expect(payload['battery_level'], 0.9);
    });

    test('reportAppLocation silently catches API errors', () async {
      when(() => apiClient.reportLocation(any()))
          .thenThrow(Exception('Network error'));

      final loc = fakeBgLocation();

      // Should not throw.
      capturedOnLocation(loc);
      await Future<void>.delayed(Duration.zero);
    });
  });

  // -----------------------------------------------------------------------
  // dispose
  // -----------------------------------------------------------------------
  group('dispose', () {
    test('closes the stream controller', () async {
      // Listen before dispose to verify the stream gets a done event.
      final done = Completer<void>();
      service.onLocation.listen((_) {}, onDone: done.complete);

      service.dispose();

      // The stream should signal done after the controller is closed.
      await done.future;
    });
  });
}
