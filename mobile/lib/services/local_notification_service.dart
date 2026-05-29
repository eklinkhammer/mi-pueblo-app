import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localNotificationServiceProvider =
    Provider<LocalNotificationService>((ref) {
  return LocalNotificationService();
});

class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  int _nextId = 0;
  void Function(String?)? _onSelectNotification;

  Future<void> initialize({
    void Function(String?)? onSelectNotification,
  }) async {
    if (onSelectNotification != null) {
      _onSelectNotification = onSelectNotification;
    }
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _onSelectNotification?.call(response.payload);
      },
    );
    _initialized = true;
  }

  Future<void> show(String title, String body, {String? payload}) async {
    if (!_initialized) {
      debugPrint('LocalNotificationService not initialized, skipping');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'geofence_events',
      'Geofence Events',
      channelDescription: 'Notifications for geofence entry and exit events',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(_nextId++, title, body, details, payload: payload);
  }
}
