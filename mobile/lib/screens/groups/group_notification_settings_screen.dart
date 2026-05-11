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
  bool _notifyHousehold = true;
  bool _notifyHomeActivity = false;
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
            _notifyHousehold = groupPrefs.notifyHousehold;
            _notifyHomeActivity = groupPrefs.notifyHomeActivity;
            _groupPrefsLoaded = true;
          }

          return ListView(
            children: [
              SwitchListTile(
                title: Text(l10n.notifyHousehold),
                subtitle: Text(l10n.notifyHouseholdSubtitle),
                value: _notifyHousehold,
                onChanged: (v) {
                  setState(() => _notifyHousehold = v);
                  _updateGroupPrefs();
                },
              ),
              SwitchListTile(
                title: Text(l10n.notifyHomeActivity),
                subtitle: Text(l10n.notifyHomeActivitySubtitle),
                value: _notifyHomeActivity,
                onChanged: (v) {
                  setState(() => _notifyHomeActivity = v);
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
          'notify_household': _notifyHousehold,
          'notify_home_activity': _notifyHomeActivity,
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
