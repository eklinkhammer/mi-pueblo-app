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
      debugPrint('[Notif] Permission status: ${settings.authorizationStatus}');
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[Notif] Permission DENIED — cannot receive notifications');
        return;
      }

      final token = await _messaging.getToken();
      debugPrint('[Notif] FCM token: ${token ?? "NULL"}');
      if (token != null) {
        await _registerToken(token);
      } else {
        debugPrint('[Notif] WARNING: FCM token is null, cannot register');
      }

      _tokenRefreshSub = _messaging.onTokenRefresh.listen(_registerToken);

      // Show local notification when FCM message arrives in foreground
      _foregroundSub = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle tap on notification that opened the app
      _messageOpenedSub =
          FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      debugPrint('[Notif] Initialization complete — listening for messages');
    } on Exception catch (e, stack) {
      debugPrint('[Notif] FAILED to initialize: $e\n$stack');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint(
        '[Notif] Foreground FCM received: notification=${message.notification?.title} data=${message.data}');
    final notification = message.notification;
    if (notification == null) {
      debugPrint('[Notif] Message has no notification payload, skipping display');
      return;
    }

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
      debugPrint('[Notif] Registering token with backend: platform=$platform token=${token.substring(0, 10)}...');
      await _apiClient.registerDeviceToken(token, platform);
      debugPrint('[Notif] Token registration SUCCESS');
    } on Exception catch (e) {
      debugPrint('[Notif] Token registration FAILED: $e');
    }
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _foregroundSub?.cancel();
    _messageOpenedSub?.cancel();
  }
}
