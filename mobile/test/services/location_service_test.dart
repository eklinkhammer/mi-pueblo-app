import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fence/services/location_service.dart';
import '../helpers/mocks.dart';
import '../helpers/fakes.dart';
import '../helpers/fake_geolocator.dart';

void main() {
  late MockApiClient mockApi;
  late FakeGeolocatorPlatform fakePlatform;
  late LocationService service;

  setUp(() {
    mockApi = MockApiClient();
    fakePlatform = FakeGeolocatorPlatform();
    GeolocatorPlatform.instance = fakePlatform;
    service = LocationService(mockApi);
  });

  tearDown(() {
    service.dispose();
  });

  group('requestPermissions', () {
    test('returns true when service enabled and permission granted', () async {
      fakePlatform.serviceEnabled = true;
      fakePlatform.permission = LocationPermission.whileInUse;

      final result = await service.requestPermissions();
      expect(result, isTrue);
    });

    test('returns false when service disabled', () async {
      fakePlatform.serviceEnabled = false;

      final result = await service.requestPermissions();
      expect(result, isFalse);
    });

    test('returns false when permission denied', () async {
      fakePlatform.serviceEnabled = true;
      fakePlatform.permission = LocationPermission.denied;

      final result = await service.requestPermissions();
      expect(result, isFalse);
    });

    test('returns false when permission deniedForever', () async {
      fakePlatform.serviceEnabled = true;
      fakePlatform.permission = LocationPermission.deniedForever;

      final result = await service.requestPermissions();
      expect(result, isFalse);
    });

    test('returns true with always permission', () async {
      fakePlatform.serviceEnabled = true;
      fakePlatform.permission = LocationPermission.always;

      final result = await service.requestPermissions();
      expect(result, isTrue);
    });
  });

  group('getCurrentPosition', () {
    test('returns position when available', () async {
      final pos = fakePosition();
      fakePlatform.position = pos;

      final result = await service.getCurrentPosition();

      expect(result, isNotNull);
      expect(result!.latitude, 37.7749);
      expect(result.longitude, -122.4194);
    });

    test('returns null on error', () async {
      fakePlatform.position = null; // will cause getCurrentPosition to throw

      final result = await service.getCurrentPosition();

      expect(result, isNull);
    });
  });

  group('startTracking', () {
    test('calls reportLocation on API client', () async {
      fakePlatform.position = fakePosition();
      fakePlatform.positionStreamController = StreamController<Position>();
      when(() => mockApi.reportLocation(any()))
          .thenAnswer((_) async => fakeResponse(null));

      service.startTracking();
      // Let the async _reportCurrentLocation() complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verify(() => mockApi.reportLocation(any())).called(1);
    });
  });

  group('stopTracking', () {
    test('cancels timer and subscription', () async {
      fakePlatform.position = fakePosition();
      final streamController = StreamController<Position>();
      fakePlatform.positionStreamController = streamController;
      when(() => mockApi.reportLocation(any()))
          .thenAnswer((_) async => fakeResponse(null));

      service.startTracking();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // Initial report happened
      clearInteractions(mockApi);
      when(() => mockApi.reportLocation(any()))
          .thenAnswer((_) async => fakeResponse(null));

      service.stopTracking();

      // Emit on stream after stop - should not trigger reportLocation
      streamController.add(fakePosition(latitude: 38.0));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verifyNever(() => mockApi.reportLocation(any()));

      await streamController.close();
    });
  });
}
