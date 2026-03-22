import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/models/geofence.dart';
import 'package:fence/services/api_client.dart';

final geofencesProvider = FutureProvider.family<List<Geofence>, String>(
  (ref, groupId) async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.getGeofences(groupId);
    final data = response.data!;
    return (data['geofences'] as List<dynamic>)
        .map((g) => Geofence.fromJson(g as Map<String, dynamic>))
        .toList();
  },
);

final geofenceSubscriptionProvider =
    FutureProvider.family<GeofenceSubscription?, String>(
  (ref, geofenceId) async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.getSubscription(geofenceId);
    final data = response.data!;
    final sub = data['subscription'];
    if (sub == null) return null;
    return GeofenceSubscription.fromJson(sub as Map<String, dynamic>);
  },
);
