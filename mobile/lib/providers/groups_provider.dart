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
    final groups = (response.data['groups'] as List)
        .map((g) => Group.fromJson(g))
        .toList();
    return groups;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchGroups());
  }

  Future<Group> createGroup(String name) async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.createGroup(name);
    final group = Group.fromJson(response.data['group']);
    await refresh();
    return group;
  }

  Future<Group> joinGroup(String inviteCode) async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.joinGroup(inviteCode);
    final group = Group.fromJson(response.data['group']);
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
  return (response.data['members'] as List)
      .map((m) => GroupMember.fromJson(m))
      .toList();
});
