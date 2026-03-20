import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
    } catch (e) {
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
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(37.7749, -122.4194),
                zoom: 14,
              ),
              onTap: (latLng) {
                setState(() => _selectedLocation = latLng);
              },
              markers: _selectedLocation != null
                  ? {
                      Marker(
                        markerId: const MarkerId('selected'),
                        position: _selectedLocation!,
                      ),
                    }
                  : {},
              circles: _selectedLocation != null
                  ? {
                      Circle(
                        circleId: const CircleId('radius'),
                        center: _selectedLocation!,
                        radius: radius,
                        fillColor: Colors.blue.withValues(alpha: 0.1),
                        strokeColor: Colors.blue,
                        strokeWidth: 2,
                      ),
                    }
                  : {},
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
