import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/l10n/app_localizations.dart';
import 'package:fence/models/stats.dart';
import 'package:fence/providers/stats_provider.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncStats = ref.watch(statsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.home)),
      body: asyncStats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(l10n.errorWithMessage(error.toString())),
        ),
        data: (stats) {
          if (stats.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(statsProvider);
                await ref.read(statsProvider.future);
              },
              child: ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          l10n.noStatsYet,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(statsProvider);
              await ref.read(statsProvider.future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: stats.length,
              itemBuilder: (context, index) =>
                  _GroupStatsCard(stats: stats[index]),
            ),
          );
        },
      ),
    );
  }
}

class _GroupStatsCard extends StatelessWidget {
  final GroupStats stats;

  const _GroupStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stats.groupName, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),

            // Home visit count
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

            // Your top places
            if (stats.yourTopGeofences.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l10n.yourTopPlaces, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              ...stats.yourTopGeofences.map(
                (g) => _VisitRow(name: g.geofenceName, count: g.visitCount),
              ),
            ],

            // Housemates
            if (stats.housemates.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l10n.housemateTopPlaces, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              ...stats.housemates.map((hm) => _HousemateSection(housemate: hm)),
            ],
          ],
        ),
      ),
    );
  }
}

class _HousemateSection extends StatelessWidget {
  final HousemateStat housemate;

  const _HousemateSection({required this.housemate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(housemate.displayName,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
              if (housemate.currentGeofenceNames.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.place, size: 14,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 2),
                    Text(
                      housemate.currentGeofenceNames.join(', '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (housemate.topGeofences.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 4),
              child: Text(l10n.noVisitsYet,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            )
          else
            ...housemate.topGeofences.map(
              (g) => Padding(
                padding: const EdgeInsets.only(left: 16),
                child: _VisitRow(name: g.geofenceName, count: g.visitCount),
              ),
            ),
        ],
      ),
    );
  }
}

class _VisitRow extends StatelessWidget {
  final String name;
  final int count;

  const _VisitRow({required this.name, required this.count});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(name)),
          Text(
            l10n.visitsCount(count),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
