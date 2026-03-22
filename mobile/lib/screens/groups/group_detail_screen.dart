import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fence/providers/groups_provider.dart';
import 'package:fence/providers/geofences_provider.dart';
import 'package:fence/services/api_client.dart';

class GroupDetailScreen extends ConsumerWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(groupMembersProvider(groupId));
    final geofencesAsync = ref.watch(geofencesProvider(groupId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _createInvite(context, ref),
            tooltip: 'Invite',
          ),
        ],
      ),
      body: ListView(
        children: [
          // Members section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Members',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          membersAsync.when(
            data: (members) => Column(
              children: members
                  .map((m) => ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(m.displayName),
                        subtitle: Text(m.role),
                      ))
                  .toList(),
            ),
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),

          const Divider(),

          // Geofences section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Geofences',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          geofencesAsync.when(
            data: (geofences) {
              if (geofences.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No geofences yet'),
                );
              }
              return Column(
                children: geofences
                    .map((g) => ListTile(
                          leading:
                              const CircleAvatar(child: Icon(Icons.location_on)),
                          title: Text(g.name),
                          subtitle: Text(
                              '${g.radiusMeters.round()}m radius'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.go(
                              '/groups/$groupId/geofences/${g.id}'),
                        ))
                    .toList(),
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/groups/$groupId/geofences/create'),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Add Geofence'),
      ),
    );
  }

  Future<void> _createInvite(BuildContext context, WidgetRef ref) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.createInvite(groupId);
      final data = response.data!;
      final invite = data['invite'] as Map<String, dynamic>;
      final code = invite['code'] as String;

      if (!context.mounted) return;
      unawaited(showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invite Code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                code,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text('Share this code with family members'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
              child: const Text('Copy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ));
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create invite: $e')),
        );
      }
    }
  }
}
