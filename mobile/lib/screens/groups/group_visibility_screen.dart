import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/l10n/app_localizations.dart';
import 'package:fence/providers/visibility_provider.dart';

class GroupVisibilityScreen extends ConsumerWidget {
  final String groupId;

  const GroupVisibilityScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairsAsync = ref.watch(visibilityProvider(groupId));
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.whoCanSeeMe)),
      body: pairsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(l10n.errorWithMessage(e.toString()))),
        data: (pairs) {
          final pending = pairs.where((p) => p.isPending).toList();
          final active = pairs.where((p) => p.isActive).toList();

          if (pairs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.noVisibilityPairsYet,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }

          return ListView(
            children: [
              if (pending.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.pendingVisibility,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                ...pending.map((pair) => ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(pair.otherDisplayName),
                      trailing: FilledButton(
                        onPressed: () => _toggleVisibility(
                            ref, groupId, pair.otherUserId, visible: true),
                        child: Text(l10n.grant),
                      ),
                    )),
                const Divider(),
              ],
              if (active.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.visibleMembers,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                ...active.map((pair) => SwitchListTile(
                      secondary: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(pair.otherDisplayName),
                      value: true,
                      onChanged: (v) {
                        if (!v) {
                          _toggleVisibility(
                              ref, groupId, pair.otherUserId, visible: false);
                        }
                      },
                    )),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleVisibility(
      WidgetRef ref, String groupId, String otherUserId,
      {required bool visible}) async {
    await ref
        .read(visibilityProvider(groupId).notifier)
        .toggleVisibility(groupId, otherUserId, visible: visible);
  }
}
