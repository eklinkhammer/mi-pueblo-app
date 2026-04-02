import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/models/visibility_pair.dart';
import 'package:fence/services/api_client.dart';

class VisibilityNotifier
    extends FamilyAsyncNotifier<List<VisibilityPair>, String> {
  @override
  Future<List<VisibilityPair>> build(String arg) async {
    return _fetch(arg);
  }

  Future<List<VisibilityPair>> _fetch(String groupId) async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.getVisibilityPairs(groupId);
    final data = response.data!;
    return (data['visibility_pairs'] as List<dynamic>)
        .map((p) => VisibilityPair.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<void> toggleVisibility(
      String groupId, String otherUserId, {required bool visible}) async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.updateVisibility(groupId, otherUserId, visible: visible);
    ref.invalidateSelf();
  }
}

final visibilityProvider = AsyncNotifierProvider.family<VisibilityNotifier,
    List<VisibilityPair>, String>(
  VisibilityNotifier.new,
);
