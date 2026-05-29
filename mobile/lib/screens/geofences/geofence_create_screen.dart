import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import 'package:fence/l10n/app_localizations.dart';
import 'package:fence/services/api_client.dart';
import 'package:fence/providers/geofences_provider.dart';
import 'package:fence/widgets/upgrade_banner.dart';

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
  bool _showUpgradeBanner = false;
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
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.addressSearchFailed)),
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
    final l10n = AppLocalizations.of(context);
    if (_nameController.text.trim().isEmpty || _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.setNameAndLocation)),
      );
      return;
    }

    final radius = double.tryParse(_radiusController.text);
    if (radius == null || radius <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.enterValidRadius)),
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
    } on DioException catch (e) {
      if (mounted) {
        if (e.response?.statusCode == 402) {
          setState(() => _showUpgradeBanner = true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.failedWithError(e.toString()))),
          );
        }
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedWithError(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final radius = double.tryParse(_radiusController.text) ?? 200;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.createGeofence)),
      body: Column(
        children: [
          if (_showUpgradeBanner)
            UpgradeBanner(message: l10n.geofenceLimitReached),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.name,
                    border: const OutlineInputBorder(),
                    hintText: l10n.nameHint,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _radiusController,
                  decoration: InputDecoration(
                    labelText: l10n.radiusMeters,
                    border: const OutlineInputBorder(),
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
                        decoration: InputDecoration(
                          labelText: l10n.searchAddress,
                          border: const OutlineInputBorder(),
                          hintText: l10n.searchAddressHint,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(l10n.searchOrTapMap),
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
        label: Text(l10n.create),
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
