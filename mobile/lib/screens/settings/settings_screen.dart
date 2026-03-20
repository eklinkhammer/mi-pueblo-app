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
            onChanged: (value) {
              setState(() => _locationSharing = value);
              final locationService = ref.read(locationServiceProvider);
              if (value) {
                locationService.startTracking();
              } else {
                locationService.stopTracking();
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
              final granted = await locationService.requestPermissions();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(granted
                        ? 'Location permission granted'
                        : 'Location permission denied'),
                  ),
                );
              }
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
              if (confirmed == true) {
                ref.read(authProvider.notifier).logout();
              }
            },
          ),
        ],
      ),
    );
  }
}
