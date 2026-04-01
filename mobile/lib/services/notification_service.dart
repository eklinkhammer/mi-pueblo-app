import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:fence/services/api_client.dart';

class NotificationService {
  final ApiClient _apiClient;
  final FirebaseMessaging? _injectedMessaging;
  StreamSubscription<String>? _tokenRefreshSub;

  NotificationService(this._apiClient, {FirebaseMessaging? messaging})
      : _injectedMessaging = messaging;

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
    } on Exception catch (e) {
      debugPrint('Failed to initialize notifications: $e');
    }
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
  }
}
