import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fence/l10n/app_localizations.dart';
import 'package:fence/providers/auth_provider.dart';
import 'package:fence/providers/stats_provider.dart';
import 'package:fence/providers/selected_group_provider.dart';
import 'package:fence/models/stats.dart';

class ShellScaffold extends ConsumerWidget {
  final Widget child;

  const ShellScaffold({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/map')) return 0;
    // index 1 is Home drawer — never "selected" since it's not a route
    if (location.startsWith('/history')) return 2;
    if (location.startsWith('/subscription')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuth =
        ref.watch(authProvider.select((s) => s.status == AuthStatus.authenticated));
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: isAuth
          ? NavigationBar(
              selectedIndex: _currentIndex(context),
              onDestinationSelected: (index) {
                switch (index) {
                  case 0:
                    context.go('/map');
                  case 1:
                    _showStatsDrawer(context, ref);
                  case 2:
                    context.go('/history');
                  case 3:
                    context.go('/subscription');
                }
              },
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.map_outlined),
                  selectedIcon: const Icon(Icons.map),
                  label: l10n.map,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home),
                  label: l10n.home,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.history_outlined),
                  selectedIcon: const Icon(Icons.history),
                  label: l10n.history,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.star_outline),
                  selectedIcon: const Icon(Icons.star),
                  label: l10n.subscription,
                ),
              ],
            )
          : null,
    );
  }

  void _showStatsDrawer(BuildContext context, WidgetRef ref) {
    // Refresh stats each time the drawer opens
    ref.invalidate(statsProvider);
    // Pre-fetch stats to center map on home when data is available
    final stats = ref.read(statsProvider).valueOrNull;
    if (stats != null && stats.isNotEmpty) {
      final first = stats.first;
      if (first.homeLatitude != null && first.homeLongitude != null) {
        // Navigate to map first, then center
        context.go('/map');
        ref.read(mapFocusLatLngProvider.notifier).state =
            (lat: first.homeLatitude!, lng: first.homeLongitude!);
      }
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _StatsSheet(),
    );
  }
}

class _StatsSheet extends ConsumerWidget {
  const _StatsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final asyncStats = ref.watch(statsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.home, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(l10n.home, style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            asyncStats.when(
              data: (stats) {
                if (stats.isEmpty) {
                  return Text(
                    l10n.noStatsYet,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: stats
                      .map((s) => _buildGroupStats(context, ref, s, l10n, theme))
                      .toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Text(l10n.errorWithMessage(e.toString())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupStats(
    BuildContext context,
    WidgetRef ref,
    GroupStats stats,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(stats.groupName, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.home, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${stats.homeGeofenceName} — ${l10n.visitsCount(stats.homeVisitCount)}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        if (stats.yourTopGeofences.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Text(l10n.yourTopPlaces, style: theme.textTheme.titleSmall),
              const SizedBox(width: 8),
              Text(l10n.allTime, style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
            ],
          ),
          const SizedBox(height: 4),
          ...stats.yourTopGeofences.map((g) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(g.geofenceName)),
                    Text(
                      l10n.visitsCount(g.visitCount),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )),
        ],
        if (stats.housemates.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Text(l10n.housemateTopPlaces, style: theme.textTheme.titleSmall),
              const SizedBox(width: 8),
              Text(l10n.allTime, style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
            ],
          ),
          const SizedBox(height: 4),
          ...stats.housemates.map((hm) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(hm.displayName,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                        if (hm.currentGeofences.isNotEmpty)
                          ...hm.currentGeofences.map((cg) => Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: InkWell(
                                  onTap: cg.latitude != null && cg.longitude != null
                                      ? () {
                                          Navigator.pop(context);
                                          context.go('/map');
                                          ref.read(mapFocusLatLngProvider.notifier).state =
                                              (lat: cg.latitude!, lng: cg.longitude!);
                                        }
                                      : null,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.place, size: 14,
                                          color: theme.colorScheme.primary),
                                      const SizedBox(width: 2),
                                      Text(
                                        cg.name,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.primary,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                      ],
                    ),
                    if (hm.topGeofences.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, top: 4),
                        child: Text(l10n.noVisitsYet,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      )
                    else
                      ...hm.topGeofences.map((g) => Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Expanded(child: Text(g.geofenceName)),
                                  Text(
                                    l10n.visitsCount(g.visitCount),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )),
                  ],
                ),
              )),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}
