import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:fence/providers/groups_provider.dart';
import 'package:fence/providers/locations_provider.dart';
import 'package:fence/providers/geofences_provider.dart';
import 'package:fence/providers/selected_group_provider.dart';
import 'package:fence/models/member_location.dart';
import 'package:fence/models/geofence.dart';
import 'package:fence/services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fence/utils/user_colors.dart';
import 'package:fence/widgets/member_marker.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  String? _centeredGroupId;
  final _mapController = MapController();
  bool _didAutoSelect = false;
  Position? _myPosition;

  @override
  void initState() {
    super.initState();
    _loadMyLocation();
  }

  Future<void> _loadMyLocation() async {
    final locationService = ref.read(locationServiceProvider);
    final hasPermission = await locationService.requestPermissions();
    if (!hasPermission) return;

    // Start background tracking so location gets reported to the API
    locationService.startTracking();

    final position = await locationService.getCurrentPosition();
    if (position != null && mounted) {
      setState(() => _myPosition = position);
    }
  }

  void _centerOnMe() {
    if (_myPosition != null) {
      _mapController.move(
        LatLng(_myPosition!.latitude, _myPosition!.longitude),
        15,
      );
    }
  }

  void _focusOnMember(MemberLocation l) {
    if (l.latitude != null && l.longitude != null) {
      _mapController.move(LatLng(l.latitude!, l.longitude!), 15);
    }
  }

  void _selectGroup(String? id) {
    final current = ref.read(selectedGroupIdProvider);
    if (id == current) return;
    ref.read(selectedGroupIdProvider.notifier).state = id;
    _centeredGroupId = null;
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsProvider);
    final selectedGroupId = ref.watch(selectedGroupIdProvider);

    // Auto-select first group once
    if (!_didAutoSelect) {
      groupsAsync.whenData((groups) {
        if (groups.isNotEmpty && selectedGroupId == null) {
          _didAutoSelect = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _selectGroup(groups.first.id);
          });
        }
      });
    }

    // Center map on first geofence when data loads for new group,
    // or on user's location if no geofences exist
    if (selectedGroupId != null && _centeredGroupId != selectedGroupId) {
      final geofencesAsync = ref.watch(geofencesProvider(selectedGroupId));
      geofencesAsync.whenData((geofences) {
        if (_centeredGroupId != selectedGroupId) {
          _centeredGroupId = selectedGroupId;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (geofences.isNotEmpty) {
              final gf = geofences.first;
              _mapController.move(LatLng(gf.latitude, gf.longitude), 15);
            } else if (_myPosition != null) {
              _mapController.move(
                LatLng(_myPosition!.latitude, _myPosition!.longitude),
                15,
              );
            }
          });
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        actions: [
          groupsAsync.when(
            data: (groups) => DropdownButton<String>(
              value: selectedGroupId,
              hint: const Text('Select group'),
              items: groups
                  .map((g) => DropdownMenuItem(
                        value: g.id,
                        child: Text(g.name),
                      ))
                  .toList(),
              onChanged: _selectGroup,
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: selectedGroupId == null
          ? const Center(child: Text('Select a group to view the map'))
          : _buildMap(),
      floatingActionButton: selectedGroupId != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_myPosition != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FloatingActionButton(
                      heroTag: 'myLocation',
                      onPressed: _centerOnMe,
                      child: const Icon(Icons.my_location),
                    ),
                  ),
                FloatingActionButton.extended(
                  heroTag: 'addGeofence',
                  onPressed: () =>
                      context.go('/groups/$selectedGroupId/geofences/create'),
                  icon: const Icon(Icons.add_location_alt),
                  label: const Text('Add Geofence'),
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildMap() {
    final groupId = ref.watch(selectedGroupIdProvider)!;
    final locationsAsync = ref.watch(groupLocationsProvider(groupId));
    final geofencesAsync = ref.watch(geofencesProvider(groupId));

    final focusUserId = ref.watch(mapFocusUserProvider);
    if (focusUserId != null) {
      ref.read(mapFocusUserProvider.notifier).state = null;
      final locations = locationsAsync.valueOrNull;
      if (locations != null) {
        final target = locations.cast<MemberLocation?>().firstWhere(
              (l) => l!.userId == focusUserId && l.latitude != null && l.longitude != null,
              orElse: () => null,
            );
        if (target != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapController.move(LatLng(target.latitude!, target.longitude!), 15);
          });
        }
      }
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(37.7749, -122.4194),
            initialZoom: 12,
            onTap: (tapPosition, latLng) => _handleMapTap(latLng, geofencesAsync),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.fence.app',
            ),
            _buildCircleLayer(geofencesAsync),
            _buildGeofenceLabelLayer(geofencesAsync),
            _buildMarkerLayer(locationsAsync),
            _buildMyLocationMarker(),
          ],
        ),
        locationsAsync.when(
          data: (locations) => locations.isEmpty
              ? const SizedBox.shrink()
              : Positioned(
                  bottom: 16,
                  left: 16,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: locations
                            .map((l) => InkWell(
                                  onTap: () => _focusOnMember(l),
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: colorForUser(l.userId),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${l.displayName} - ${_timeAgo(l.updatedAt)}',
                                          style:
                                              Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
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
                width: 60,
                height: 48,
                child: MemberMarker(
                  userId: l.userId,
                  displayName: l.displayName,
                  timeAgo: _timeAgo(l.updatedAt),
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

  MarkerLayer _buildMyLocationMarker() {
    if (_myPosition == null) return const MarkerLayer(markers: []);
    return MarkerLayer(markers: [
      Marker(
        point: LatLng(_myPosition!.latitude, _myPosition!.longitude),
        width: 20,
        height: 20,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 3,
              ),
            ],
          ),
        ),
      ),
    ]);
  }

  void _handleMapTap(LatLng point, AsyncValue<List<Geofence>> geofencesAsync) {
    final geofences = geofencesAsync.valueOrNull;
    if (geofences == null) return;

    final groupId = ref.read(selectedGroupIdProvider);
    if (groupId == null) return;

    const distance = Distance();
    Geofence? smallest;
    for (final g in geofences) {
      final center = LatLng(g.latitude, g.longitude);
      final meters = distance.as(LengthUnit.Meter, point, center);
      if (meters <= g.radiusMeters) {
        if (smallest == null || g.radiusMeters < smallest.radiusMeters) {
          smallest = g;
        }
      }
    }
    if (smallest != null) {
      context.go('/groups/$groupId/geofences/${smallest.id}');
    }
  }

  MarkerLayer _buildGeofenceLabelLayer(AsyncValue<List<Geofence>> geofencesAsync) {
    final markers = geofencesAsync.when(
      data: (geofences) => geofences
          .map((g) => Marker(
                point: LatLng(g.latitude, g.longitude),
                width: 120,
                height: 24,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      g.name,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ))
          .toList(),
      loading: () => <Marker>[],
      error: (_, _) => <Marker>[],
    );
    return MarkerLayer(markers: markers);
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
