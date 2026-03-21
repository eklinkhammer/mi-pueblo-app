import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:fence/providers/groups_provider.dart';
import 'package:fence/providers/locations_provider.dart';
import 'package:fence/providers/geofences_provider.dart';
import 'package:fence/models/member_location.dart';
import 'package:fence/models/geofence.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  String? _selectedGroupId;

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        actions: [
          // Group selector dropdown
          groupsAsync.when(
            data: (groups) => DropdownButton<String>(
              value: _selectedGroupId,
              hint: const Text('Select group'),
              items: groups
                  .map((g) => DropdownMenuItem(
                        value: g.id,
                        child: Text(g.name),
                      ))
                  .toList(),
              onChanged: (id) => setState(() => _selectedGroupId = id),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: _selectedGroupId == null
          ? const Center(child: Text('Select a group to view the map'))
          : _buildMap(),
    );
  }

  Widget _buildMap() {
    final locationsAsync =
        ref.watch(groupLocationsProvider(_selectedGroupId!));
    final geofencesAsync =
        ref.watch(geofencesProvider(_selectedGroupId!));

    return Stack(
      children: [
        FlutterMap(
          options: const MapOptions(
            initialCenter: LatLng(37.7749, -122.4194),
            initialZoom: 12,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.fence.app',
            ),
            _buildCircleLayer(geofencesAsync),
            _buildMarkerLayer(locationsAsync),
          ],
        ),
        // Legend overlay
        Positioned(
          bottom: 16,
          left: 16,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: locationsAsync.when(
                data: (locations) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: locations
                      .map((l) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '${l.displayName} - ${_timeAgo(l.updatedAt)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ))
                      .toList(),
                ),
                loading: () =>
                    const CircularProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  MarkerLayer _buildMarkerLayer(AsyncValue<List<MemberLocation>> locationsAsync) {
    final markers = locationsAsync.when(
      data: (locations) => locations
          .where((l) => l.latitude != null && l.longitude != null)
          .map((l) => Marker(
                point: LatLng(l.latitude!, l.longitude!),
                width: 40,
                height: 40,
                child: Tooltip(
                  message: '${l.displayName}\n${_timeAgo(l.updatedAt)}',
                  child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                ),
              ))
          .toList(),
      loading: () => <Marker>[],
      error: (_, _) => <Marker>[],
    );
    return MarkerLayer(markers: markers);
  }

  CircleLayer _buildCircleLayer(AsyncValue<List<Geofence>> geofencesAsync) {
    final circles = geofencesAsync.when(
      data: (geofences) => geofences
          .map((g) => CircleMarker(
                point: LatLng(g.latitude, g.longitude),
                radius: g.radiusMeters,
                useRadiusInMeter: true,
                color: Colors.blue.withValues(alpha: 0.1),
                borderColor: Colors.blue.withValues(alpha: 0.5),
                borderStrokeWidth: 2,
              ))
          .toList(),
      loading: () => <CircleMarker>[],
      error: (_, _) => <CircleMarker>[],
    );
    return CircleLayer(circles: circles);
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
