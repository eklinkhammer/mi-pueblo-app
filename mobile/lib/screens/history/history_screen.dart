import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/l10n/app_localizations.dart';
import 'package:fence/providers/auth_provider.dart';
import 'package:fence/providers/history_provider.dart';
import 'package:fence/widgets/history_event_list.dart';

class HistoryScreen extends ConsumerWidget {
  final String? userId;

  const HistoryScreen({super.key, this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(authProvider).user?.id;
    final targetUserId = userId ?? currentUserId;
    final l10n = AppLocalizations.of(context);

    if (targetUserId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.history)),
        body: Center(child: Text(l10n.noHistoryYet)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.history)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(historyProvider(targetUserId));
          await ref.read(historyProvider(targetUserId).future);
        },
        child: HistoryEventList(userId: targetUserId),
      ),
    );
  }
}
