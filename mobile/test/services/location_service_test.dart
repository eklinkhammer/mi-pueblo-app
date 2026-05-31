import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fence/models/app_location.dart';
import 'package:fence/models/app_geofence.dart';
import 'package:fence/services/location_service.dart';
import '../helpers/fakes.dart';
import '../helpers/mocks.dart';

// ---------------------------------------------------------------------------
// Mock / Fake helpers
// ---------------------------------------------------------------------------

class MockGeolocationBackend extends Mock implements GeolocationBackend {}

AppLocation fakeAppLocation({
  double latitude = 37.7749,
  double longitude = -122.4194,
  double accuracy = 10.0,
  double altitude = 50.0,
  double speed = 1.5,
  double heading = 90.0,
  double? batteryLevel = 0.85,
}) {
  return AppLocation(
    latitude: latitude,
    longitude: longitude,
    accuracy: accuracy,
    altitude: altitude,
    speed: speed,
    heading: heading,
    batteryLevel: batteryLevel,
  );
}

void main() {
  late MockGeolocationBackend backend;
  late MockApiClient apiClient;
  late LocationService service;
  late StreamController<AppLocation> locationStreamController;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(<AppGeofence>[]);
  });

  setUp(() {
    backend = MockGeolocationBackend();
    apiClient = MockApiClient();
    locationStreamController = StreamController<AppLocation>.broadcast();
    service = LocationService(apiClient, backend);

    // Default stubs — individual tests can override.
    when(() => backend.configure(
          distanceFilter: any(named: 'distanceFilter'),
          intervalMs: any(named: 'intervalMs'),
          debug: any(named: 'debug'),
        )).thenAnswer((_) async {});
    when(() => backend.start()).thenAnswer((_) async {});
    when(() => backend.stop()).thenAnswer((_) async {});
    when(() => backend.onLocation)
        .thenAnswer((_) => locationStreamController.stream);
    when(() => apiClient.reportLocation(any()))
        .thenAnswer((_) async => fakeResponse({'status': 'ok'}));
  });

  tearDown(() {
    service.dispose();
    locationStreamController.close();
  });

  // -----------------------------------------------------------------------
  // requestPermissions
  // -----------------------------------------------------------------------
  group('requestPermissions', () {
    test('returns granted', () async {
      when(() => backend.requestPermission())
          .thenAnswer((_) async => AppPermissionStatus.granted);

      expect(
          await service.requestPermissions(), AppPermissionStatus.granted);
    });

    test('returns denied', () async {
      when(() => backend.requestPermission())
          .thenAnswer((_) async => AppPermissionStatus.denied);

      expect(
          await service.requestPermissions(), AppPermissionStatus.denied);
    });

    test('returns notDetermined', () async {
      when(() => backend.requestPermission())
          .thenAnswer((_) async => AppPermissionStatus.notDetermined);

      expect(await service.requestPermissions(),
          AppPermissionStatus.notDetermined);
    });
  });

  // -----------------------------------------------------------------------
  // getCurrentPosition
  // -----------------------------------------------------------------------
  group('getCurrentPosition', () {
    test('returns AppLocation with correct field mapping', () async {
      final loc = fakeAppLocation(
        latitude: 40.0,
        longitude: -74.0,
        accuracy: 5.0,
        altitude: 100.0,
        speed: 3.0,
        heading: 180.0,
        batteryLevel: 0.6,
      );
      when(() => backend.getCurrentPosition())
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
      when(() => backend.getCurrentPosition())
          .thenThrow(Exception('GPS unavailable'));

      expect(await service.getCurrentPosition(), isNull);
    });
  });

  // -----------------------------------------------------------------------
  // startTracking / stopTracking
  // -----------------------------------------------------------------------
  group('startTracking', () {
    test('calls configure then start', () async {
      await service.startTracking();

      verify(() => backend.configure(
            distanceFilter: any(named: 'distanceFilter'),
            intervalMs: any(named: 'intervalMs'),
            debug: any(named: 'debug'),
          )).called(1);
      verify(() => backend.start()).called(1);
    });

    test('configure is idempotent — called only once', () async {
      await service.startTracking();
      await service.startTracking();

      verify(() => backend.configure(
            distanceFilter: any(named: 'distanceFilter'),
            intervalMs: any(named: 'intervalMs'),
            debug: any(named: 'debug'),
          )).called(1);
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
    setUp(() async {
      // Trigger configuration so the backend stream is subscribed.
      await service.startTracking();
    });

    test('onLocation stream emits and reports to API', () async {
      final loc = fakeAppLocation(latitude: 51.5, longitude: -0.1);

      final future = service.onLocation.first;
      locationStreamController.add(loc);
      final emitted = await future;

      expect(emitted.latitude, 51.5);
      expect(emitted.longitude, -0.1);

      // Give the async _reportAppLocation a tick to complete.
      await Future<void>.delayed(Duration.zero);
      verify(() => apiClient.reportLocation(any())).called(1);
    });

    test('reportAppLocation sends correct payload shape', () async {
      final loc = fakeAppLocation(
        latitude: 35.0,
        longitude: 139.0,
        accuracy: 8.0,
        altitude: 20.0,
        speed: 2.0,
        heading: 45.0,
        batteryLevel: 0.9,
      );

      locationStreamController.add(loc);
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

      final loc = fakeAppLocation();

      // Should not throw.
      locationStreamController.add(loc);
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
