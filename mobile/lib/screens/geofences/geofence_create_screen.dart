import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:fence/services/api_client.dart';
import 'package:fence/providers/geofences_provider.dart';

class GeofenceCreateScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GeofenceCreateScreen({super.key, required this.groupId});

  @override
  ConsumerState<GeofenceCreateScreen> createState() =>
      _GeofenceCreateScreenState();
}

class _GeofenceCreateScreenState extends ConsumerState<GeofenceCreateScreen> {
  final _nameController = TextEditingController();
  final _radiusController = TextEditingController(text: '200');
  final _searchController = TextEditingController();
  final _mapController = MapController();
  LatLng? _selectedLocation;
  bool _loading = false;
  bool _searching = false;
  List<_SearchResult> _searchResults = [];

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _searching = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.geocode(query);
      final data = response.data!;
      final results = (data['results'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((r) => _SearchResult(
                displayName: r['display_name'] as String,
                lat: (r['lat'] as num).toDouble(),
                lng: (r['lng'] as num).toDouble(),
              ))
          .toList();
      setState(() => _searchResults = results);
    } on Exception catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address search failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectSearchResult(_SearchResult result) {
    final latLng = LatLng(result.lat, result.lng);
    setState(() {
      _selectedLocation = latLng;
      _searchResults = [];
      _searchController.clear();
    });
    _mapController.move(latLng, 16);
  }

  Future<void> _create() async {
    if (_nameController.text.trim().isEmpty || _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a name and select a location')),
      );
      return;
    }

    final radius = double.tryParse(_radiusController.text);
    if (radius == null || radius <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid radius')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.createGeofence(widget.groupId, {
        'name': _nameController.text.trim(),
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'radius_meters': radius,
      });

      // Invalidate cache
      ref.invalidate(geofencesProvider(widget.groupId));

      if (mounted) {
        context.go('/groups/${widget.groupId}');
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = double.tryParse(_radiusController.text) ?? 200;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Geofence')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Home, School, Office',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _radiusController,
                  decoration: const InputDecoration(
                    labelText: 'Radius (meters)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'Search address',
                          border: OutlineInputBorder(),
                          hintText: 'e.g., 123 Main St',
                        ),
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _searching ? null : _search,
                      icon: _searching
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.search),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_searchResults.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      result.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _selectSearchResult(result),
                  );
                },
              ),
            ),
          if (_searchResults.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Search for an address or tap the map to place the geofence center'),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(37.7749, -122.4194),
                initialZoom: 14,
                onTap: (tapPosition, latLng) {
                  setState(() {
                    _selectedLocation = latLng;
                    _searchResults = [];
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.fence.app',
                ),
                if (_selectedLocation != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _selectedLocation!,
                        radius: radius,
                        useRadiusInMeter: true,
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderColor: Colors.blue,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                if (_selectedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedLocation!,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _create,
        icon: _loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.check),
        label: const Text('Create'),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _radiusController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

class _SearchResult {
  final String displayName;
  final double lat;
  final double lng;

  _SearchResult({
    required this.displayName,
    required this.lat,
    required this.lng,
  });
}
