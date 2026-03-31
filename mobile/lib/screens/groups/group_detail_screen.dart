import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fence/l10n/app_localizations.dart';
import 'package:fence/providers/groups_provider.dart';
import 'package:fence/providers/geofences_provider.dart';
import 'package:fence/providers/selected_group_provider.dart';
import 'package:fence/services/api_client.dart';

class GroupDetailScreen extends ConsumerWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(groupMembersProvider(groupId));
    final geofencesAsync = ref.watch(geofencesProvider(groupId));
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.group),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _createInvite(context, ref),
            tooltip: l10n.invite,
          ),
        ],
      ),
      body: ListView(
        children: [
          // Members section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.members,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          membersAsync.when(
            data: (members) => Column(
              children: members
                  .map((m) => ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(m.displayName),
                        subtitle: Text(m.role),
                        onTap: () {
                          ref.read(mapFocusUserProvider.notifier).state = m.id;
                          ref.read(selectedGroupIdProvider.notifier).state = groupId;
                          context.go('/map');
                        },
                      ))
                  .toList(),
            ),
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text(l10n.errorWithMessage(e.toString()))),
          ),

          const Divider(),

          // Geofences section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.geofences,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          geofencesAsync.when(
            data: (geofences) {
              if (geofences.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.noGeofencesYet),
                );
              }
              return Column(
                children: geofences
                    .map((g) => ListTile(
                          leading:
                              const CircleAvatar(child: Icon(Icons.location_on)),
                          title: Text(g.name),
                          subtitle: Text(
                              l10n.radiusWithValue(g.radiusMeters.round())),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.go(
                              '/groups/$groupId/geofences/${g.id}'),
                        ))
                    .toList(),
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text(l10n.errorWithMessage(e.toString()))),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/groups/$groupId/geofences/create'),
        icon: const Icon(Icons.add_location_alt),
        label: Text(l10n.addGeofence),
      ),
    );
  }

  Future<void> _createInvite(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.createInvite(groupId);
      final data = response.data!;
      final invite = data['invite'] as Map<String, dynamic>;
      final code = invite['code'] as String;

      if (!context.mounted) return;
      unawaited(showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final dl10n = AppLocalizations.of(dialogContext);
          return AlertDialog(
            title: Text(dl10n.inviteCode),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SelectableText(
                  code,
                  style: Theme.of(dialogContext).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(dl10n.shareCodeWithFamily),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(dl10n.copiedToClipboard)),
                  );
                },
                child: Text(dl10n.copy),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(dl10n.done),
              ),
            ],
          );
        },
      ));
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToCreateInvite(e.toString()))),
        );
      }
    }
  }
}
