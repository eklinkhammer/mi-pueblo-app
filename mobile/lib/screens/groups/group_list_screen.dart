import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fence/l10n/app_localizations.dart';
import 'package:fence/providers/groups_provider.dart';

class GroupListScreen extends ConsumerWidget {
  const GroupListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.groups),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text(l10n.createGroup),
            onPressed: () => context.go('/groups/create'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.group_add),
            label: Text(l10n.joinGroup),
            onPressed: () => context.go('/groups/join'),
          ),
        ],
      ),
      body: groupsAsync.when(
        data: (groups) {
          if (groups.isEmpty) {
            return Center(
              child: Text(l10n.noGroupsYet),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(groupsProvider.notifier).refresh(),
            child: ListView.builder(
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.group)),
                  title: Text(group.name),
                  subtitle: Text(l10n.sharingWithCount(group.sharingCount)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/groups/${group.id}'),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text(l10n.errorWithMessage(error.toString()))),
      ),
    );
  }
}
