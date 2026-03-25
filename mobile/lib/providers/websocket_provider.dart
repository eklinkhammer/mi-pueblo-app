import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/providers/auth_provider.dart';
import 'package:fence/providers/groups_provider.dart';
import 'package:fence/services/websocket_service.dart';

final websocketManagerProvider = Provider<void>((ref) {
  final auth = ref.watch(authProvider);
  final wsService = ref.read(websocketServiceProvider);

  if (auth.status != AuthStatus.authenticated) {
    wsService.dispose();
    return;
  }

  wsService.connect();

  ref.listen(groupsProvider, (previous, next) {
    next.whenData((groupList) {
      final desired = groupList.map((g) => g.id).toSet();
      final current = wsService.joinedGroupIds;

      for (final id in desired.difference(current)) {
        wsService.joinGroup(id);
      }
      for (final id in current.difference(desired)) {
        wsService.leaveGroup(id);
      }
    });
  }, fireImmediately: true);

  ref.onDispose(wsService.dispose);
});
