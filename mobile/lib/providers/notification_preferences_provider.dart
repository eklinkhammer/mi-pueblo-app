import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/models/notification_preferences.dart';
import 'package:fence/services/api_client.dart';

final groupNotificationPrefsProvider = FutureProvider.family<
    GroupNotificationPreferences, String>((ref, groupId) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.getNotificationPreferences(groupId);
  return GroupNotificationPreferences.fromJson(response.data!);
});

final memberNotificationPrefsProvider = FutureProvider.family<
    List<MemberNotificationPreference>, String>((ref, groupId) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.getMemberPreferences(groupId);
  final data = response.data!;
  return (data['preferences'] as List<dynamic>)
      .map((p) =>
          MemberNotificationPreference.fromJson(p as Map<String, dynamic>))
      .toList();
});
