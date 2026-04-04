import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/providers/auth_provider.dart';
import 'package:fence/services/local_notification_service.dart';
import 'package:fence/services/websocket_service.dart';

final geofenceNotificationProvider = Provider<void>((ref) {
  final auth = ref.watch(authProvider);
  if (auth.status != AuthStatus.authenticated || auth.user == null) return;

  final currentUserId = auth.user!.id;
  final localNotifications = ref.read(localNotificationServiceProvider);
  final wsService = ref.read(websocketServiceProvider);

  // Initialize local notifications
  unawaited(localNotifications.initialize());

  final subscription = wsService.messages
      .where((msg) {
        final event = msg['event'] as String?;
        return event == 'geofence:entered' || event == 'geofence:exited';
      })
      .listen((msg) {
        final payload = msg['payload'] as Map<String, dynamic>;
        final userId = payload['user_id'] as String?;

        // Don't notify about own events
        if (userId == currentUserId) return;

        final displayName = payload['display_name'] as String? ?? 'Someone';
        final geofenceName =
            payload['geofence_name'] as String? ?? 'a geofence';
        final event = payload['event'] as String?;

        final action = event == 'entered' ? 'arrived at' : 'left';
        final title = '$displayName $action $geofenceName';
        final body = event == 'entered'
            ? '$displayName has entered $geofenceName'
            : '$displayName has left $geofenceName';

        localNotifications.show(title, body, payload: payload['geofence_id'] as String?);
      });

  ref.onDispose(subscription.cancel);
});
