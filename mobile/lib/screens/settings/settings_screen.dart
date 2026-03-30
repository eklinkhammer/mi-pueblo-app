import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/providers/auth_provider.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Profile section
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(authState.user?.displayName ?? 'Unknown'),
            subtitle: Text(authState.user?.email ?? ''),
          ),
          const Divider(),

          // Location sharing toggle
          SwitchListTile(
            title: const Text('Location Sharing'),
            subtitle: const Text('Share your location with group members'),
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
            title: const Text('Location Permissions'),
            subtitle: const Text('Manage location access'),
            onTap: () async {
              final locationService = ref.read(locationServiceProvider);
              final status = await locationService.requestPermissions();
              if (!context.mounted) return;
              final message = switch (status) {
                PermissionStatus.granted =>
                  'Location permission granted',
                PermissionStatus.denied =>
                  'Location permission denied. Enable it in device Settings.',
                PermissionStatus.notDetermined =>
                  'Location permission not determined. Please try again.',
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
            title: const Text('Sign Out',
                style: TextStyle(color: Colors.red)),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Sign Out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
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
}
