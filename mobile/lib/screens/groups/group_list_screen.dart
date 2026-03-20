import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fence/providers/groups_provider.dart';

class GroupListScreen extends ConsumerWidget {
  const GroupListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: () => context.go('/groups/join'),
            tooltip: 'Join Group',
          ),
        ],
      ),
      body: groupsAsync.when(
        data: (groups) {
          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No groups yet'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go('/groups/create'),
                    child: const Text('Create a Group'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => context.go('/groups/join'),
                    child: const Text('Join with Invite Code'),
                  ),
                ],
              ),
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
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/groups/${group.id}'),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/groups/create'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
