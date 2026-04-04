import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:fence/services/api_client.dart';
import 'package:fence/services/local_notification_service.dart';

class NotificationService {
  final ApiClient _apiClient;
  final LocalNotificationService _localNotifications;
  final FirebaseMessaging? _injectedMessaging;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _messageOpenedSub;

  NotificationService(
    this._apiClient,
    this._localNotifications, {
    FirebaseMessaging? messaging,
  }) : _injectedMessaging = messaging;

  FirebaseMessaging get _messaging =>
      _injectedMessaging ?? FirebaseMessaging.instance;

  Future<void> initialize() async {
    try {
      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Notification permission denied');
        return;
      }

      final token = await _messaging.getToken();
      if (token != null) {
        await _registerToken(token);
      }

      _tokenRefreshSub = _messaging.onTokenRefresh.listen(_registerToken);

      // Show local notification when FCM message arrives in foreground
      _foregroundSub = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle tap on notification that opened the app
      _messageOpenedSub =
          FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    } on Exception catch (e) {
      debugPrint('Failed to initialize notifications: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.title ?? '',
      notification.body ?? '',
      payload: message.data['geofence_id'] as String?,
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.data}');
  }

  Future<void> _registerToken(String token) async {
    try {
      final platform = Platform.isIOS ? 'ios' : 'android';
      await _apiClient.registerDeviceToken(token, platform);
      debugPrint('FCM token registered');
    } on Exception catch (e) {
      debugPrint('Failed to register FCM token: $e');
    }
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _foregroundSub?.cancel();
    _messageOpenedSub?.cancel();
  }
}
