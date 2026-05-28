import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/models/member_location.dart';
import 'package:fence/models/geofence_presence.dart';
import 'package:fence/providers/auth_provider.dart';
import 'package:fence/services/api_client.dart';
import 'package:fence/services/websocket_service.dart';

class GroupLocationsNotifier
    extends FamilyAsyncNotifier<List<MemberLocation>, String> {
  StreamSubscription<Map<String, dynamic>>? _locationSubscription;
  StreamSubscription<Map<String, dynamic>>? _visibilitySubscription;
  StreamSubscription<Map<String, dynamic>>? _geofenceSubscription;
  Timer? _pollTimer;

  @override
  Future<List<MemberLocation>> build(String arg) async {
    final locations = await _fetchLocations(arg);
    _listenToWebSocket(arg);
    _startPeriodicRefresh(arg);
    ref.onDispose(() {
      _locationSubscription?.cancel();
      _visibilitySubscription?.cancel();
      _geofenceSubscription?.cancel();
      _pollTimer?.cancel();
    });
    return locations;
  }

  Future<List<MemberLocation>> _fetchLocations(String groupId) async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.getGroupLocations(groupId);
    final data = response.data!;

    // Parse geofence presence and update the separate provider
    final presenceList = data['geofence_presence'] as List<dynamic>?;
    if (presenceList != null) {
      final presence = presenceList
          .map((p) => GeofencePresence.fromJson(p as Map<String, dynamic>))
          .toList();
      ref.read(groupGeofencePresenceProvider(groupId).notifier).state = presence;
    }

    return (data['locations'] as List<dynamic>)
        .map((l) => MemberLocation.fromJson(l as Map<String, dynamic>))
        .toList();
  }

  void _listenToWebSocket(String groupId) {
    final wsService = ref.read(websocketServiceProvider);
    _locationSubscription = wsService.messages
        .where((msg) =>
            msg['topic'] == 'group:$groupId' &&
            msg['event'] == 'location:updated')
        .listen((msg) {
      final payload = msg['payload'] as Map<String, dynamic>;
      _applyLocationUpdate(payload);
    });

    // Re-fetch locations when visibility changes
    _visibilitySubscription = wsService.messages
        .where((msg) =>
            msg['topic'] == 'group:$groupId' &&
            msg['event'] == 'visibility:changed')
        .listen((_) async {
      try {
        final locations = await _fetchLocations(groupId);
        state = AsyncValue.data(locations);
      } on Exception catch (e) {
        developer.log(
          'Visibility-triggered refresh failed for group $groupId',
          error: e,
          name: 'GroupLocationsNotifier',
        );
      }
    });

    // Listen for geofence enter/exit events
    _geofenceSubscription = wsService.messages
        .where((msg) =>
            msg['topic'] == 'group:$groupId' &&
            (msg['event'] == 'geofence:entered' ||
                msg['event'] == 'geofence:exited'))
        .listen((msg) {
      final payload = msg['payload'] as Map<String, dynamic>;
      final event = msg['event'] as String;
      _applyGeofenceEvent(groupId, payload, event);
    });
  }

  void _applyLocationUpdate(Map<String, dynamic> payload) {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = MemberLocation.fromJson(payload);
    // Only update existing entries; new users appear on next poll
    final newList = current.map((loc) {
      return loc.userId == updated.userId ? updated : loc;
    }).toList();

    state = AsyncValue.data(newList);
  }

  void _applyGeofenceEvent(
      String groupId, Map<String, dynamic> payload, String event) {
    // Filter out events where the current user is not in the visible_to list
    // (but always allow through events triggered by the current user themselves)
    final currentUserId = ref.read(authProvider).user?.id;
    final triggeringUserId = payload['user_id'] as String?;
    final visibleTo = payload['visible_to'] as List<dynamic>?;
    if (visibleTo != null && triggeringUserId != currentUserId) {
      if (currentUserId != null && !visibleTo.contains(currentUserId)) {
        return;
      }
    }

    final current = ref.read(groupGeofencePresenceProvider(groupId));
    final userId = payload['user_id'] as String;

    if (event == 'geofence:entered') {
      final lat = payload['geofence_latitude'] as num?;
      final lng = payload['geofence_longitude'] as num?;
      if (lat == null || lng == null) return;

      final entry = GeofencePresence(
        userId: userId,
        displayName: payload['display_name'] as String,
        sharingMode: (payload['sharing_mode'] as String?) ?? '',
        geofenceId: payload['geofence_id'] as String,
        geofenceName: payload['geofence_name'] as String,
        geofenceLatitude: lat.toDouble(),
        geofenceLongitude: lng.toDouble(),
        enteredAt: DateTime.now(),
      );
      final deduplicated = current
          .where((p) => !(p.userId == userId && p.geofenceId == entry.geofenceId))
          .toList();
      ref.read(groupGeofencePresenceProvider(groupId).notifier).state = [
        ...deduplicated,
        entry,
      ];
    } else if (event == 'geofence:exited') {
      final geofenceId = payload['geofence_id'] as String;
      ref.read(groupGeofencePresenceProvider(groupId).notifier).state = current
          .where((p) => !(p.userId == userId && p.geofenceId == geofenceId))
          .toList();
    }
  }

  void _startPeriodicRefresh(String groupId) {
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      try {
        final locations = await _fetchLocations(groupId);
        state = AsyncValue.data(locations);
      } on Exception catch (e) {
        developer.log(
          'Polling locations failed for group $groupId',
          error: e,
          name: 'GroupLocationsNotifier',
        );
      }
    });
  }
}

final groupLocationsProvider = AsyncNotifierProvider.family<
    GroupLocationsNotifier, List<MemberLocation>, String>(
  GroupLocationsNotifier.new,
);

final groupGeofencePresenceProvider =
    StateProvider.family<List<GeofencePresence>, String>(
  (ref, groupId) => [],
);
