import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/models/dwell_session.dart';
import 'package:fence/models/category_watch.dart';
import 'package:fence/services/api_client.dart';

final userDwellsProvider =
    FutureProvider.family<List<DwellSession>, String>((ref, userId) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.getUserDwells(userId);
  final data = response.data!;
  final dwells = (data['dwells'] as List<dynamic>)
      .map((d) => DwellSession.fromJson(d as Map<String, dynamic>))
      .toList();
  return dwells;
});

final categoriesProvider = FutureProvider<List<String>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.getCategories();
  final data = response.data!;
  return (data['categories'] as List<dynamic>).cast<String>();
});

final categoryWatchesProvider =
    AsyncNotifierProvider<CategoryWatchesNotifier, List<CategoryWatch>>(
  CategoryWatchesNotifier.new,
);

class CategoryWatchesNotifier extends AsyncNotifier<List<CategoryWatch>> {
  @override
  Future<List<CategoryWatch>> build() async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.getCategoryWatches();
    final data = response.data!;
    return (data['watches'] as List<dynamic>)
        .map((w) => CategoryWatch.fromJson(w as Map<String, dynamic>))
        .toList();
  }

  Future<void> createWatch(String watchedUserId, String category) async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.createCategoryWatch(watchedUserId, category);
    ref.invalidateSelf();
  }

  Future<void> deleteWatch(String watchId) async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.deleteCategoryWatch(watchId);
    ref.invalidateSelf();
  }
}
