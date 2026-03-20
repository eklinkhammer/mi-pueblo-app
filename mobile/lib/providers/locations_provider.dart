import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/models/member_location.dart';
import 'package:fence/services/api_client.dart';

final groupLocationsProvider =
    FutureProvider.family<List<MemberLocation>, String>(
  (ref, groupId) async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.getGroupLocations(groupId);
    return (response.data['locations'] as List)
        .map((l) => MemberLocation.fromJson(l))
        .toList();
  },
);
