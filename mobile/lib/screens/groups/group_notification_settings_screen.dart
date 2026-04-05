import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/l10n/app_localizations.dart';
import 'package:fence/providers/notification_preferences_provider.dart';
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
  bool _groupPrefsLoaded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groupPrefsAsync =
        ref.watch(groupNotificationPrefsProvider(widget.groupId));

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

          return ListView(
            children: [
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
}
