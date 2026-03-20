import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
        GoogleMap(
          onMapCreated: (_) {},
          initialCameraPosition: const CameraPosition(
            target: LatLng(37.7749, -122.4194), // Default SF
            zoom: 12,
          ),
          markers: _buildMarkers(locationsAsync),
          circles: _buildCircles(geofencesAsync),
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
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

  Set<Marker> _buildMarkers(AsyncValue<List<MemberLocation>> locationsAsync) {
    return locationsAsync.when(
      data: (locations) => locations
          .where((l) => l.latitude != null && l.longitude != null)
          .map((l) => Marker(
                markerId: MarkerId(l.userId),
                position: LatLng(l.latitude!, l.longitude!),
                infoWindow: InfoWindow(
                  title: l.displayName,
                  snippet: _timeAgo(l.updatedAt),
                ),
              ))
          .toSet(),
      loading: () => {},
      error: (_, _) => {},
    );
  }

  Set<Circle> _buildCircles(AsyncValue<List<Geofence>> geofencesAsync) {
    return geofencesAsync.when(
      data: (geofences) => geofences
          .map((g) => Circle(
                circleId: CircleId(g.id),
                center: LatLng(g.latitude, g.longitude),
                radius: g.radiusMeters,
                fillColor: Colors.blue.withValues(alpha: 0.1),
                strokeColor: Colors.blue.withValues(alpha: 0.5),
                strokeWidth: 2,
              ))
          .toSet(),
      loading: () => {},
      error: (_, _) => {},
    );
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
