import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:fence/services/api_client.dart';
import 'package:fence/providers/geofences_provider.dart';

class GeofenceDetailScreen extends ConsumerWidget {
  final String groupId;
  final String geofenceId;

  const GeofenceDetailScreen({
    super.key,
    required this.groupId,
    required this.geofenceId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final geofencesAsync = ref.watch(geofencesProvider(groupId));
    final subscriptionAsync =
        ref.watch(geofenceSubscriptionProvider(geofenceId));

    return geofencesAsync.when(
      data: (geofences) {
        final geofence = geofences.where((g) => g.id == geofenceId).firstOrNull;
        if (geofence == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Geofence not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(geofence.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _delete(context, ref),
              ),
            ],
          ),
          body: ListView(
            children: [
              SizedBox(
                height: 250,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter:
                        LatLng(geofence.latitude, geofence.longitude),
                    initialZoom: 15,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.fence.app',
                    ),
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: LatLng(geofence.latitude, geofence.longitude),
                          radius: geofence.radiusMeters,
                          useRadiusInMeter: true,
                          color: Colors.blue.withValues(alpha: 0.15),
                          borderColor: Colors.blue,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(geofence.latitude, geofence.longitude),
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ListTile(
                title: const Text('Radius'),
                subtitle: Text('${geofence.radiusMeters.round()} meters'),
              ),
              if (geofence.description != null)
                ListTile(
                  title: const Text('Description'),
                  subtitle: Text(geofence.description!),
                ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Notifications',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              subscriptionAsync.when(
                data: (sub) => Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Notify on Entry'),
                      value: sub?.notifyOnEntry ?? false,
                      onChanged: (value) => _updateSubscription(
                          ref, {'notify_on_entry': value}),
                    ),
                    SwitchListTile(
                      title: const Text('Notify on Exit'),
                      value: sub?.notifyOnExit ?? false,
                      onChanged: (value) => _updateSubscription(
                          ref, {'notify_on_exit': value}),
                    ),
                  ],
                ),
                loading: () => const Center(
                    child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.visibility_off),
                title: const Text('Opt out of this geofence'),
                subtitle: const Text(
                    "Your location won't trigger notifications for this fence"),
                onTap: () => _optOut(context, ref),
              ),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _updateSubscription(
      WidgetRef ref, Map<String, dynamic> data) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.upsertSubscription(geofenceId, data);
      ref.invalidate(geofenceSubscriptionProvider(geofenceId));
    } on Exception catch (_) {
      // Silently fail
    }
  }

  Future<void> _optOut(BuildContext context, WidgetRef ref) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.createOptOut(geofenceId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opted out successfully')),
        );
      }
    } on Exception catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Already opted out')),
        );
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Geofence?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      try {
        final apiClient = ref.read(apiClientProvider);
        await apiClient.deleteGeofence(groupId, geofenceId);
        ref.invalidate(geofencesProvider(groupId));
        if (context.mounted) {
          context.go('/groups/$groupId');
        }
      } on Exception catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e')),
          );
        }
      }
    }
  }
}
