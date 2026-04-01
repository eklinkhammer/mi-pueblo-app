import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/l10n/app_localizations.dart';
import 'package:fence/models/notification_preferences.dart';
import 'package:fence/providers/groups_provider.dart';
import 'package:fence/providers/notification_preferences_provider.dart';
import 'package:fence/providers/auth_provider.dart';
import 'package:fence/services/api_client.dart';

class GroupNotificationSettingsScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupNotificationSettingsScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupNotificationSettingsScreen> createState() =>
      _GroupNotificationSettingsScreenState();
}

class _GroupNotificationSettingsScreenState
    extends ConsumerState<GroupNotificationSettingsScreen> {
  bool _silenceAll = false;
  bool _silenceHome = false;
  bool _notifyHousehold = true;
  Map<String, MemberNotificationPreference> _memberPrefs = {};
  bool _groupPrefsLoaded = false;
  bool _memberPrefsLoaded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groupPrefsAsync =
        ref.watch(groupNotificationPrefsProvider(widget.groupId));
    final memberPrefsAsync =
        ref.watch(memberNotificationPrefsProvider(widget.groupId));
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationSettings)),
      body: groupPrefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(l10n.errorWithMessage(e.toString()))),
        data: (groupPrefs) {
          if (!_groupPrefsLoaded) {
            _silenceAll = groupPrefs.silenceAllNotifications;
            _silenceHome = groupPrefs.silenceHomeNotifications;
            _notifyHousehold = groupPrefs.notifyHousehold;
            _groupPrefsLoaded = true;
          }

          if (!_memberPrefsLoaded) {
            memberPrefsAsync.whenData((prefs) {
              _memberPrefs = {for (final p in prefs) p.subjectId: p};
              _memberPrefsLoaded = true;
            });
          }

          return ListView(
            children: [
              // Group-level toggles
              SwitchListTile(
                title: Text(l10n.silenceAllNotifications),
                subtitle: Text(l10n.silenceAllNotificationsSubtitle),
                value: _silenceAll,
                onChanged: (v) {
                  setState(() => _silenceAll = v);
                  _updateGroupPrefs();
                },
              ),
              SwitchListTile(
                title: Text(l10n.silenceHomeNotifications),
                subtitle: Text(l10n.silenceHomeNotificationsSubtitle),
                value: _silenceHome,
                onChanged: _silenceAll
                    ? null
                    : (v) {
                        setState(() => _silenceHome = v);
                        _updateGroupPrefs();
                      },
              ),
              SwitchListTile(
                title: Text(l10n.notifyHousehold),
                subtitle: Text(l10n.notifyHouseholdSubtitle),
                value: _notifyHousehold,
                onChanged: (v) {
                  setState(() => _notifyHousehold = v);
                  _updateGroupPrefs();
                },
              ),

              const Divider(),

              // Per-member section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.memberNotifications,
                    style: Theme.of(context).textTheme.titleMedium),
              ),

              membersAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text(l10n.errorWithMessage(e.toString()))),
                data: (members) {
                  final currentUserId = ref.read(authProvider).user?.id;
                  final others = members
                      .where((m) => m.id != currentUserId)
                      .toList();
                  return Column(
                    children: others.map((member) {
                      final pref = _memberPrefs[member.id];
                      final notify = pref?.notify ?? true;
                      final notifyHome = pref?.notifyHome ?? true;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Text(member.displayName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall),
                          ),
                          SwitchListTile(
                            title: Text(l10n.notifications),
                            value: notify,
                            onChanged: _silenceAll
                                ? null
                                : (v) {
                                    _updateMemberPref(member.id, notify: v,
                                        notifyHome: notifyHome);
                                  },
                          ),
                          SwitchListTile(
                            title: Text(l10n.homeNotifications),
                            value: notifyHome,
                            onChanged: (!notify || _silenceAll)
                                ? null
                                : (v) {
                                    _updateMemberPref(member.id,
                                        notify: notify, notifyHome: v);
                                  },
                          ),
                          const Divider(indent: 16),
                        ],
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateGroupPrefs() async {
    try {
      await ref.read(apiClientProvider).updateNotificationPreferences(
        widget.groupId,
        {
          'silence_all_notifications': _silenceAll,
          'silence_home_notifications': _silenceHome,
          'notify_household': _notifyHousehold,
        },
      );
      ref.invalidate(groupNotificationPrefsProvider(widget.groupId));
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)
                  .errorWithMessage(e.toString()))),
        );
      }
    }
  }

  Future<void> _updateMemberPref(String subjectId,
      {required bool notify, required bool notifyHome}) async {
    setState(() {
      _memberPrefs[subjectId] = MemberNotificationPreference(
        subjectId: subjectId,
        notify: notify,
        notifyHome: notifyHome,
      );
    });

    try {
      await ref.read(apiClientProvider).upsertMemberPreference(
        widget.groupId,
        subjectId,
        {'notify': notify, 'notify_home': notifyHome},
      );
      ref.invalidate(memberNotificationPrefsProvider(widget.groupId));
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)
                  .errorWithMessage(e.toString()))),
        );
      }
    }
  }
}
