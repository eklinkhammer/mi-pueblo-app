import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/l10n/app_localizations.dart';
import 'package:fence/providers/auth_provider.dart';
import 'package:fence/providers/locale_provider.dart';
import 'package:fence/services/location_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _locationSharing = true;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final locale = ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context);

    String languageLabel;
    if (locale == null) {
      languageLabel = l10n.systemDefault;
    } else if (locale.languageCode == 'es') {
      languageLabel = l10n.spanish;
    } else {
      languageLabel = l10n.english;
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          // Profile section
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(authState.user?.displayName ?? l10n.unknown),
            subtitle: Text(authState.user?.email ?? ''),
          ),
          const Divider(),

          // Language selector
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            subtitle: Text(languageLabel),
            onTap: () => _showLanguagePicker(context),
          ),

          // Location sharing toggle
          SwitchListTile(
            title: Text(l10n.locationSharing),
            subtitle: Text(l10n.locationSharingSubtitle),
            value: _locationSharing,
            onChanged: (value) async {
              setState(() => _locationSharing = value);
              final locationService = ref.read(locationServiceProvider);
              if (value) {
                await locationService.startTracking();
              } else {
                await locationService.stopTracking();
              }
            },
          ),

          // Permissions
          ListTile(
            leading: const Icon(Icons.location_on),
            title: Text(l10n.locationPermissions),
            subtitle: Text(l10n.manageLocationAccess),
            onTap: () async {
              final locationService = ref.read(locationServiceProvider);
              final status = await locationService.requestPermissions();
              if (!context.mounted) return;
              final message = switch (status) {
                PermissionStatus.granted => l10n.locationPermissionGranted,
                PermissionStatus.denied =>
                  l10n.locationPermissionDeniedSettings,
                PermissionStatus.notDetermined =>
                  l10n.locationPermissionNotDetermined,
              };
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message)),
              );
            },
          ),

          const Divider(),

          // Logout
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(l10n.signOut,
                style: const TextStyle(color: Colors.red)),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) {
                  final dl10n = AppLocalizations.of(dialogContext);
                  return AlertDialog(
                    title: Text(dl10n.signOutConfirm),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(dialogContext, false),
                        child: Text(dl10n.cancel),
                      ),
                      FilledButton(
                        onPressed: () =>
                            Navigator.pop(dialogContext, true),
                        child: Text(dl10n.signOut),
                      ),
                    ],
                  );
                },
              );
              if (confirmed ?? false) {
                unawaited(ref.read(authProvider.notifier).logout());
              }
            },
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.read(localeProvider);

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(l10n.systemDefault),
                leading: Icon(locale == null
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off),
                onTap: () {
                  ref.read(localeProvider.notifier).setLocale(null);
                  Navigator.pop(sheetContext);
                },
              ),
              ListTile(
                title: Text(l10n.english),
                leading: Icon(locale?.languageCode == 'en'
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off),
                onTap: () {
                  ref
                      .read(localeProvider.notifier)
                      .setLocale(const Locale('en'));
                  Navigator.pop(sheetContext);
                },
              ),
              ListTile(
                title: Text(l10n.spanish),
                leading: Icon(locale?.languageCode == 'es'
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off),
                onTap: () {
                  ref
                      .read(localeProvider.notifier)
                      .setLocale(const Locale('es'));
                  Navigator.pop(sheetContext);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
