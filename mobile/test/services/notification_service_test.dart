import 'dart:async';

import 'package:fence/services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fakes.dart';
import '../helpers/mocks.dart';

class MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

class MockNotificationSettings extends Mock implements NotificationSettings {}

void main() {
  late MockApiClient mockApi;
  late MockFirebaseMessaging mockMessaging;
  late MockNotificationSettings mockSettings;
  late StreamController<String> tokenRefreshController;

  setUp(() {
    mockApi = MockApiClient();
    mockMessaging = MockFirebaseMessaging();
    mockSettings = MockNotificationSettings();
    tokenRefreshController = StreamController<String>();

    when(() => mockMessaging.onTokenRefresh)
        .thenAnswer((_) => tokenRefreshController.stream);
  });

  tearDown(() {
    tokenRefreshController.close();
  });

  NotificationService createService() =>
      NotificationService(mockApi, MockLocalNotificationService(),
          messaging: mockMessaging);

  void stubPermissionGranted() {
    when(() => mockMessaging.requestPermission(
          alert: any(named: 'alert'),
          announcement: any(named: 'announcement'),
          badge: any(named: 'badge'),
          carPlay: any(named: 'carPlay'),
          criticalAlert: any(named: 'criticalAlert'),
          provisional: any(named: 'provisional'),
          sound: any(named: 'sound'),
        )).thenAnswer((_) async => mockSettings);
    when(() => mockSettings.authorizationStatus)
        .thenReturn(AuthorizationStatus.authorized);
    when(() => mockMessaging.getInitialMessage())
        .thenAnswer((_) async => null);
  }

  void stubPermissionDenied() {
    when(() => mockMessaging.requestPermission(
          alert: any(named: 'alert'),
          announcement: any(named: 'announcement'),
          badge: any(named: 'badge'),
          carPlay: any(named: 'carPlay'),
          criticalAlert: any(named: 'criticalAlert'),
          provisional: any(named: 'provisional'),
          sound: any(named: 'sound'),
        )).thenAnswer((_) async => mockSettings);
    when(() => mockSettings.authorizationStatus)
        .thenReturn(AuthorizationStatus.denied);
  }

  group('initialize', () {
    test('registers token when permission granted', () async {
      stubPermissionGranted();
      when(() => mockMessaging.getToken())
          .thenAnswer((_) async => 'test-fcm-token');
      when(() => mockApi.registerDeviceToken(any(), any()))
          .thenAnswer((_) async => fakeResponse({'ok': true}));

      final service = createService();
      await service.initialize();

      verify(() => mockApi.registerDeviceToken('test-fcm-token', any()))
          .called(1);
    });

    test('does not register when permission denied', () async {
      stubPermissionDenied();

      final service = createService();
      await service.initialize();

      verifyNever(() => mockMessaging.getToken());
      verifyNever(() => mockApi.registerDeviceToken(any(), any()));
    });

    test('skips registration when token is null', () async {
      stubPermissionGranted();
      when(() => mockMessaging.getToken()).thenAnswer((_) async => null);

      final service = createService();
      await service.initialize();

      verifyNever(() => mockApi.registerDeviceToken(any(), any()));
    });

    test('handles token registration error gracefully', () async {
      stubPermissionGranted();
      when(() => mockMessaging.getToken())
          .thenAnswer((_) async => 'test-token');
      when(() => mockApi.registerDeviceToken(any(), any()))
          .thenThrow(Exception('network error'));

      final service = createService();
      // Should not throw despite API error
      await service.initialize();
    });
  });

  group('token refresh', () {
    test('re-registers when token refreshes', () async {
      stubPermissionGranted();
      when(() => mockMessaging.getToken())
          .thenAnswer((_) async => 'initial-token');
      when(() => mockApi.registerDeviceToken(any(), any()))
          .thenAnswer((_) async => fakeResponse({'ok': true}));

      final service = createService();
      await service.initialize();

      tokenRefreshController.add('refreshed-token');
      await Future<void>.delayed(Duration.zero);

      verify(() => mockApi.registerDeviceToken('refreshed-token', any()))
          .called(1);
    });
  });

  group('dispose', () {
    test('stops listening for token refreshes', () async {
      stubPermissionGranted();
      when(() => mockMessaging.getToken())
          .thenAnswer((_) async => 'test-token');
      when(() => mockApi.registerDeviceToken(any(), any()))
          .thenAnswer((_) async => fakeResponse({'ok': true}));

      final service = createService();
      await service.initialize();
      service.dispose();

      tokenRefreshController.add('after-dispose-token');
      await Future<void>.delayed(Duration.zero);

      // Only the initial registration, not the post-dispose one
      verify(() => mockApi.registerDeviceToken(any(), any())).called(1);
    });

    test('safe to call before initialize', () {
      final service = createService();
      // Should not throw
      service.dispose();
    });
  });
}
