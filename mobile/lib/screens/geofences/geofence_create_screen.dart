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
  LatLng? _selectedLocation;
  bool _loading = false;

  Future<void> _create() async {
    if (_nameController.text.trim().isEmpty || _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a name and tap the map to select a location')),
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
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Tap the map to place the geofence center'),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: const LatLng(37.7749, -122.4194),
                initialZoom: 14,
                onTap: (tapPosition, latLng) {
                  setState(() => _selectedLocation = latLng);
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
    super.dispose();
  }
}
