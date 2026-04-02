import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/models/member_location.dart';
import 'package:fence/services/api_client.dart';
import 'package:fence/services/websocket_service.dart';

class GroupLocationsNotifier
    extends FamilyAsyncNotifier<List<MemberLocation>, String> {
  StreamSubscription<Map<String, dynamic>>? _locationSubscription;
  StreamSubscription<Map<String, dynamic>>? _visibilitySubscription;
  Timer? _pollTimer;

  @override
  Future<List<MemberLocation>> build(String arg) async {
    final locations = await _fetchLocations(arg);
    _listenToWebSocket(arg);
    _startPeriodicRefresh(arg);
    ref.onDispose(() {
      _locationSubscription?.cancel();
      _visibilitySubscription?.cancel();
      _pollTimer?.cancel();
    });
    return locations;
  }

  Future<List<MemberLocation>> _fetchLocations(String groupId) async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.getGroupLocations(groupId);
    final data = response.data!;
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
