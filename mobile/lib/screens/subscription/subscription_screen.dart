import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/l10n/app_localizations.dart';
import 'package:fence/models/subscription.dart';
import 'package:fence/providers/subscription_provider.dart';
import 'package:fence/services/revenuecat_service.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _purchasing = false;
  bool _restoring = false;

  String _tierDisplayName(SubscriptionTier tier, AppLocalizations l10n) {
    switch (tier) {
      case SubscriptionTier.villageMember:
        return l10n.villageMember;
      case SubscriptionTier.villageElder:
        return l10n.villageElder;
      case SubscriptionTier.villageLeader:
        return l10n.villageLeader;
    }
  }

  String _tierPrice(SubscriptionTier tier, AppLocalizations l10n) {
    switch (tier) {
      case SubscriptionTier.villageMember:
        return l10n.freeTier;
      case SubscriptionTier.villageElder:
        return '\$4.99${l10n.perMonth}';
      case SubscriptionTier.villageLeader:
        return '\$9.99${l10n.perMonth}';
    }
  }

  String _limitDisplay(int value, AppLocalizations l10n) {
    return value == -1 ? l10n.unlimited : '$value';
  }

  Future<void> _purchase(SubscriptionTier tier) async {
    setState(() => _purchasing = true);
    try {
      final offerings = await RevenueCatService.getOfferings();
      if (offerings == null || offerings.current == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No offerings available')),
          );
        }
        return;
      }

      const packageId = r'$rc_monthly';
      final package = offerings.current!.availablePackages.firstWhere(
        (p) => p.identifier == packageId,
        orElse: () => offerings.current!.availablePackages.first,
      );

      await RevenueCatService.purchase(package);
      ref.invalidate(subscriptionProvider);
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _restoring = true);
    try {
      await RevenueCatService.restorePurchases();
      ref.invalidate(subscriptionProvider);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.restorePurchasesSuccess)),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subAsync = ref.watch(subscriptionProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.subscription)),
      body: subAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorUnknown)),
        data: (sub) {
          final currentTier = sub?.tier ?? SubscriptionTier.villageMember;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Current plan header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.currentPlan,
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        _tierDisplayName(currentTier, l10n),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (sub?.currentPeriodEnd != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${l10n.renewsOn} ${_formatDate(sub!.currentPeriodEnd!)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Tier comparison cards
              for (final tier in SubscriptionTier.values) ...[
                _TierCard(
                  tierName: _tierDisplayName(tier, l10n),
                  price: _tierPrice(tier, l10n),
                  isCurrent: tier == currentTier,
                  features: [
                    '${l10n.groupsYouCanCreate}: ${_limitDisplay(
                      tier == SubscriptionTier.villageMember
                          ? 1
                          : tier == SubscriptionTier.villageElder
                              ? 3
                              : -1,
                      l10n,
                    )}',
                    '${l10n.groupsYouCanJoin}: ${l10n.unlimited}',
                    '${l10n.membersPerGroup}: ${tier == SubscriptionTier.villageMember ? 10 : tier == SubscriptionTier.villageElder ? 50 : 100}',
                    '${l10n.geofencesPerGroup}: ${_limitDisplay(
                      tier == SubscriptionTier.villageMember ? 3 : -1,
                      l10n,
                    )}',
                    '${l10n.historyRetention}: ${tier == SubscriptionTier.villageMember ? 7 : 90} ${l10n.days}',
                  ],
                  onUpgrade: tier.index > currentTier.index && !_purchasing
                      ? () => _purchase(tier)
                      : null,
                  purchasing: _purchasing,
                  l10n: l10n,
                ),
                const SizedBox(height: 12),
              ],

              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _restoring ? null : _restore,
                child: _restoring
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.restorePurchases),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}

class _TierCard extends StatelessWidget {
  final String tierName;
  final String price;
  final bool isCurrent;
  final List<String> features;
  final VoidCallback? onUpgrade;
  final bool purchasing;
  final AppLocalizations l10n;

  const _TierCard({
    required this.tierName,
    required this.price,
    required this.isCurrent,
    required this.features,
    required this.onUpgrade,
    required this.purchasing,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrent
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(tierName,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                if (isCurrent)
                  Chip(
                    label: Text(l10n.currentPlan),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            Text(price,
                style: theme.textTheme.titleLarge
                    ?.copyWith(color: theme.colorScheme.primary)),
            const SizedBox(height: 8),
            for (final feature in features)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(feature, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            if (onUpgrade != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onUpgrade,
                  child: purchasing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(l10n.upgrade),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
