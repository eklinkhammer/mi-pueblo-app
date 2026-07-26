import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/models/dwell_session.dart';
import 'package:fence/models/category_watch.dart';
import 'package:fence/providers/dwell_provider.dart';

class UserDetailScreen extends ConsumerWidget {
  final String userId;
  final String? displayName;

  const UserDetailScreen({
    super.key,
    required this.userId,
    this.displayName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dwellsAsync = ref.watch(userDwellsProvider(userId));
    final watchesAsync = ref.watch(categoryWatchesProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName ?? 'User Profile'),
      ),
      body: ListView(
        children: [
          // Recent Places section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Recent Places',
                style: theme.textTheme.titleMedium),
          ),
          dwellsAsync.when(
            data: (dwells) {
              if (dwells.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('No recent places detected yet.'),
                );
              }
              return Column(
                children: dwells.map((d) => _buildDwellTile(d, theme)).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error loading dwells: $e'),
            ),
          ),

          const Divider(),

          // Category Watches section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Category Watches',
                style: theme.textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Get notified when this person visits a type of place.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 8),
          categoriesAsync.when(
            data: (categories) => watchesAsync.when(
              data: (watches) => _buildCategoryToggles(
                context, ref, categories, watches, theme,
              ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error loading watches: $e'),
              ),
            ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error loading categories: $e'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDwellTile(DwellSession dwell, ThemeData theme) {
    final icon = _categoryIcon(dwell.category);
    final subtitle = [
      if (dwell.displayCategory.isNotEmpty) dwell.displayCategory,
      if (dwell.formattedDuration.isNotEmpty) dwell.formattedDuration,
    ].join(' \u2022 ');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
      ),
      title: Text(
        dwell.displayName ?? 'Unknown place',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(subtitle),
      trailing: Text(
        _timeAgo(dwell.startedAt),
        style: theme.textTheme.bodySmall,
      ),
    );
  }

  Widget _buildCategoryToggles(
    BuildContext context,
    WidgetRef ref,
    List<String> categories,
    List<CategoryWatch> watches,
    ThemeData theme,
  ) {
    // Build a set of categories that have an active watch for this user
    final activeCategories = <String>{};
    final watchIdByCategory = <String, String>{};
    for (final w in watches) {
      if (w.watchedUserId == userId && w.active) {
        activeCategories.add(w.category);
        watchIdByCategory[w.category] = w.id;
      }
    }

    return Column(
      children: categories.map((category) {
        final isActive = activeCategories.contains(category);
        final displayName = category.replaceAll('_', ' ');
        final icon = _categoryIcon(category);

        return SwitchListTile(
          secondary: Icon(icon),
          title: Text(displayName[0].toUpperCase() + displayName.substring(1)),
          value: isActive,
          onChanged: (value) async {
            try {
              if (value) {
                await ref
                    .read(categoryWatchesProvider.notifier)
                    .createWatch(userId, category);
              } else {
                final watchId = watchIdByCategory[category];
                if (watchId != null) {
                  await ref
                      .read(categoryWatchesProvider.notifier)
                      .deleteWatch(watchId);
                }
              }
            } on Exception catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            }
          },
        );
      }).toList(),
    );
  }

  static IconData _categoryIcon(String? category) {
    return switch (category) {
      'coffee_shop' => Icons.coffee,
      'restaurant' => Icons.restaurant,
      'bar' => Icons.local_bar,
      'gym' => Icons.fitness_center,
      'hospital' => Icons.local_hospital,
      'pharmacy' => Icons.local_pharmacy,
      'grocery_store' => Icons.shopping_cart,
      'shopping' => Icons.shopping_bag,
      'school' => Icons.school,
      'library' => Icons.local_library,
      'place_of_worship' => Icons.church,
      'park' => Icons.park,
      'entertainment' => Icons.movie,
      'office' => Icons.business,
      'gas_station' => Icons.local_gas_station,
      _ => Icons.place,
    };
  }

  static String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
