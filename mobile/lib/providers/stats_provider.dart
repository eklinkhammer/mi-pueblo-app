import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/models/stats.dart';
import 'package:fence/services/api_client.dart';

final statsProvider = FutureProvider<List<GroupStats>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.getStats();
  final data = response.data!;
  final stats = (data['stats'] as List)
      .map((e) => GroupStats.fromJson(e as Map<String, dynamic>))
      .toList();
  return stats;
});
