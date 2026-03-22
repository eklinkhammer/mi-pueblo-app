import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/models/group.dart';
import 'package:fence/services/api_client.dart';

final groupsProvider =
    AsyncNotifierProvider<GroupsNotifier, List<Group>>(GroupsNotifier.new);

class GroupsNotifier extends AsyncNotifier<List<Group>> {
  @override
  Future<List<Group>> build() async {
    return _fetchGroups();
  }

  Future<List<Group>> _fetchGroups() async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.getGroups();
    final data = response.data!;
    final groups = (data['groups'] as List<dynamic>)
        .map((g) => Group.fromJson(g as Map<String, dynamic>))
        .toList();
    return groups;
  }

  Future<void> refresh() async {
    state = const AsyncValue<List<Group>>.loading();
    state = await AsyncValue.guard(_fetchGroups);
  }

  Future<Group> createGroup(String name) async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.createGroup(name);
    final data = response.data!;
    final group = Group.fromJson(data['group'] as Map<String, dynamic>);
    await refresh();
    return group;
  }

  Future<Group> joinGroup(String inviteCode) async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.joinGroup(inviteCode);
    final data = response.data!;
    final group = Group.fromJson(data['group'] as Map<String, dynamic>);
    await refresh();
    return group;
  }

  Future<void> deleteGroup(String id) async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.deleteGroup(id);
    await refresh();
  }
}

final groupMembersProvider =
    FutureProvider.family<List<GroupMember>, String>((ref, groupId) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.getMembers(groupId);
  final data = response.data!;
  return (data['members'] as List<dynamic>)
      .map((m) => GroupMember.fromJson(m as Map<String, dynamic>))
      .toList();
});
