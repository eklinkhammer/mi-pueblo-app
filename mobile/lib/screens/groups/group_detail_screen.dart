import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fence/l10n/app_localizations.dart';
import 'package:fence/models/visibility_pair.dart';
import 'package:fence/providers/auth_provider.dart';
import 'package:fence/providers/groups_provider.dart';
import 'package:fence/providers/geofences_provider.dart';
import 'package:fence/providers/selected_group_provider.dart';
import 'package:fence/providers/sharing_mode_provider.dart';
import 'package:fence/providers/visibility_provider.dart';
import 'package:fence/services/api_client.dart';

class GroupDetailScreen extends ConsumerWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(groupMembersProvider(groupId));
    final geofencesAsync = ref.watch(geofencesProvider(groupId));
    final pairs = ref.watch(visibilityProvider(groupId)).valueOrNull;
    final currentUserId = ref.watch(authProvider).user?.id;
    final l10n = AppLocalizations.of(context);

    final isAdmin = membersAsync.whenOrNull(
          data: (members) => members.any(
            (m) => m.id == currentUserId && m.role == 'admin',
          ),
        ) ??
        false;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.group),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () =>
                context.go('/groups/$groupId/notification-settings'),
            tooltip: l10n.notificationSettings,
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _createInvite(context, ref),
            tooltip: l10n.invite,
          ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteGroup(context, ref),
            ),
          if (!isAdmin)
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: () => _leaveGroup(context, ref),
              tooltip: l10n.leave,
            ),
        ],
      ),
      body: ListView(
        children: [
          // Sharing mode card
          _buildSharingModeCard(context, ref, l10n),

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
                        trailing: _buildVisibilityControl(
                            ref, m.id, currentUserId, pairs, l10n),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(l10n.geofences,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add_location_alt, size: 18),
                  label: Text(l10n.addGeofence),
                  onPressed: () => context.go('/groups/$groupId/geofences/create'),
                ),
              ],
            ),
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
    );
  }

  Widget _buildSharingModeCard(
      BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final sharingModeAsync = ref.watch(sharingModeProvider(groupId));

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.locationSharingMode,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: sharingModeAsync.when(
                data: (mode) => SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'live', label: Text(l10n.live)),
                    ButtonSegment(
                        value: 'geofences', label: Text(l10n.geofencesOnly)),
                  ],
                  selected: {mode},
                  onSelectionChanged: (selected) {
                    ref
                        .read(sharingModeProvider(groupId).notifier)
                        .setMode(selected.first);
                  },
                ),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Text(l10n.errorWithMessage(e.toString())),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildVisibilityControl(
      WidgetRef ref, String memberId, String? currentUserId,
      List<VisibilityPair>? pairs, AppLocalizations l10n) {
    if (memberId == currentUserId || pairs == null) return null;
    final matching = pairs.where((p) => p.otherUserId == memberId);
    if (matching.isEmpty) return null;
    final pair = matching.first;

    if (pair.isPending) {
      return FilledButton(
        onPressed: () => _toggleVisibility(ref, pair.otherUserId, visible: true),
        child: Text(l10n.share),
      );
    }
    if (pair.isActive) {
      return Switch(
        value: true,
        onChanged: (v) {
          if (!v) {
            _toggleVisibility(ref, pair.otherUserId, visible: false);
          }
        },
      );
    }
    return null;
  }

  Future<void> _toggleVisibility(
      WidgetRef ref, String otherUserId, {required bool visible}) async {
    await ref
        .read(visibilityProvider(groupId).notifier)
        .toggleVisibility(groupId, otherUserId, visible: visible);
  }

  Future<void> _deleteGroup(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dl10n = AppLocalizations.of(dialogContext);
        return AlertDialog(
          title: Text(dl10n.deleteGroup),
          content: Text(dl10n.deleteCannotBeUndone),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(dl10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(dl10n.delete),
            ),
          ],
        );
      },
    );

    if (confirmed ?? false) {
      try {
        await ref.read(groupsProvider.notifier).deleteGroup(groupId);
        if (ref.read(selectedGroupIdProvider) == groupId) {
          ref.read(selectedGroupIdProvider.notifier).state = null;
        }
        if (context.mounted) {
          context.go('/groups');
        }
      } on Exception catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.failedWithError(e.toString()))),
          );
        }
      }
    }
  }

  Future<void> _leaveGroup(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dl10n = AppLocalizations.of(dialogContext);
        return AlertDialog(
          title: Text(dl10n.leaveGroup),
          content: Text(dl10n.leaveGroupConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(dl10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(dl10n.leave),
            ),
          ],
        );
      },
    );

    if (confirmed ?? false) {
      try {
        await ref.read(groupsProvider.notifier).leaveGroup(groupId);
        if (ref.read(selectedGroupIdProvider) == groupId) {
          ref.read(selectedGroupIdProvider.notifier).state = null;
        }
        if (context.mounted) {
          context.go('/groups');
        }
      } on Exception catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.failedWithError(e.toString()))),
          );
        }
      }
    }
  }

  Future<void> _createInvite(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.createInvite(groupId);
      final data = response.data!;
      final invite = data['invite'] as Map<String, dynamic>;
      final code = invite['code'] as String;
      final url = invite['url'] as String? ?? 'https://fence.app/join/$code';

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
              TextButton(
                onPressed: () {
                  Share.share(dl10n.inviteShareMessage(url));
                },
                child: Text(dl10n.share),
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
