import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fence/l10n/app_localizations.dart';

class UpgradeBanner extends StatelessWidget {
  final String message;

  const UpgradeBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.star, color: theme.colorScheme.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => context.go('/subscription'),
            child: Text(l10n.upgrade),
          ),
        ],
      ),
    );
  }
}
