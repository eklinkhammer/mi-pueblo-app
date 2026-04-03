import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/providers/auth_provider.dart';
import 'package:fence/providers/groups_provider.dart';
import 'package:fence/services/geofence_sync_service.dart';
import 'package:fence/providers/geofences_provider.dart';
import 'package:fence/services/websocket_service.dart';

final geofenceSyncManagerProvider = Provider<void>((ref) {
  final auth = ref.watch(authProvider);
  if (auth.status != AuthStatus.authenticated) return;

  final syncService = ref.read(geofenceSyncServiceProvider);

  // Start listening for native geofence events
  syncService.startListening();

  // Initial sync
  syncService.syncGeofences();

  // Re-sync when groups change
  ref.listen(groupsProvider, (previous, next) {
    next.whenData((_) {
      syncService.syncGeofences();
    });
  });

  // Re-sync when geofences:changed arrives via WebSocket
  final wsService = ref.read(websocketServiceProvider);
  final subscription = wsService.messages.listen((message) {
    if (message['event'] == 'geofences:changed') {
      syncService.syncGeofences();
      // Refresh the UI provider for this group
      final topic = message['topic'] as String?;
      if (topic != null && topic.startsWith('group:')) {
        final groupId = topic.replaceFirst('group:', '');
        ref.invalidate(geofencesProvider(groupId));
      }
    }
  });

  ref.onDispose(() {
    subscription.cancel();
    syncService.dispose();
  });
});
