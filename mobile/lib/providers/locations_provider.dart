import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/models/member_location.dart';
import 'package:fence/services/api_client.dart';

final groupLocationsProvider =
    FutureProvider.family<List<MemberLocation>, String>(
  (ref, groupId) async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.getGroupLocations(groupId);
    final data = response.data!;
    return (data['locations'] as List<dynamic>)
        .map((l) => MemberLocation.fromJson(l as Map<String, dynamic>))
        .toList();
  },
);
