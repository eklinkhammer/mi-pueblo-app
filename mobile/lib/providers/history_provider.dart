import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/models/geofence_event.dart';
import 'package:fence/services/api_client.dart';

final historyProvider =
    FutureProvider.family<List<GeofenceEvent>, String>((ref, userId) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.getUserHistory(userId);
  final data = response.data!;
  final events = (data['events'] as List)
      .map((e) => GeofenceEvent.fromJson(e as Map<String, dynamic>))
      .toList();
  return events;
});
