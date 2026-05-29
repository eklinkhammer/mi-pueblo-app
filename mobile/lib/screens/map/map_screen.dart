import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:fence/l10n/app_localizations.dart';
import 'package:fence/providers/groups_provider.dart';
import 'package:fence/providers/locations_provider.dart';
import 'package:fence/providers/geofences_provider.dart';
import 'package:fence/providers/selected_group_provider.dart';
import 'package:fence/models/member_location.dart';
import 'package:fence/models/geofence.dart';
import 'package:fence/models/geofence_event.dart';
import 'package:fence/models/geofence_presence.dart';
import 'package:fence/models/app_location.dart';
import 'package:fence/providers/auth_provider.dart';
import 'package:fence/providers/history_provider.dart';
import 'package:fence/services/api_client.dart';
import 'package:fence/services/location_service.dart';
import 'package:fence/utils/user_colors.dart';
import 'package:fence/widgets/history_event_list.dart';
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
  bool _didInitialCenter = false;
  AppLocation? _myPosition;
  StreamSubscription<AppLocation>? _locationSubscription;

  @override
  void initState() {
    super.initState();
    _loadMyLocation();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadMyLocation() async {
    final locationService = ref.read(locationServiceProvider);

    _locationSubscription = locationService.onLocation.listen((loc) {
      if (mounted) setState(() => _myPosition = loc);
    });

    final position = await locationService.getCurrentPosition();
    if (position != null && mounted) {
      setState(() => _myPosition = position);
      _autoCenterOnFirstPosition();
    }
  }

  void _autoCenterOnFirstPosition() {
    if (_didInitialCenter || _myPosition == null) return;
    _didInitialCenter = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(
        LatLng(_myPosition!.latitude, _myPosition!.longitude),
        15,
      );
    });
  }

  Future<void> _centerOnMe() async {
    final locationService = ref.read(locationServiceProvider);
    final position = await locationService.getCurrentPosition();
    if (position != null && mounted) {
      setState(() => _myPosition = position);
    }
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

  void _focusOnPresence(GeofencePresence p) {
    if (p.geofenceLatitude != null && p.geofenceLongitude != null) {
      _mapController.move(LatLng(p.geofenceLatitude!, p.geofenceLongitude!), 15);
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
    return _buildAuthenticatedView(context);
  }

  Widget _buildAnonymousView(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _myPosition != null
                  ? LatLng(_myPosition!.latitude, _myPosition!.longitude)
                  : const LatLng(37.7749, -122.4194),
              initialZoom: 12,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.fence.app',
              ),
              _buildMyLocationMarker(),
            ],
          ),
          Positioned(
            bottom: 32,
            left: 32,
            right: 32,
            child: FilledButton(
              onPressed: () => _showJoinSheet(context),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(l10n.joinGroup),
            ),
          ),
        ],
      ),
      floatingActionButton: _myPosition != null
          ? Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: FloatingActionButton(
                heroTag: 'myLocation',
                onPressed: _centerOnMe,
                child: const Icon(Icons.my_location),
              ),
            )
          : null,
    );
  }

  void _showJoinSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.8,
          minChildSize: 0.3,
          expand: false,
          builder: (_, scrollController) {
            return _JoinSheetBody(scrollController: scrollController);
          },
        );
      },
    );
  }

  Widget _buildAuthenticatedView(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
      body: Stack(
        children: [
          // Full-screen map
          selectedGroupId == null ? _buildBasicMap() : _buildMap(),
          // Top-center floating group selector
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
                child: groupsAsync.when(
                    data: (groups) {
                      if (groups.isEmpty) {
                        return FilledButton(
                          onPressed: () => _showJoinSheet(context),
                          child: const Text('Join My Village'),
                        );
                      }
                      final effectiveId = (selectedGroupId != null &&
                              groups.any((g) => g.id == selectedGroupId))
                          ? selectedGroupId
                          : null;
                      if (effectiveId != selectedGroupId) {
                        _didAutoSelect = false;
                      }
                      final topBarTheme = Theme.of(context);
                      final cardColor = topBarTheme.colorScheme.primaryContainer;
                      final iconColor = topBarTheme.colorScheme.onPrimaryContainer;
                      return Row(
                        children: [
                          Expanded(
                            child: Card(
                              color: cardColor,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: DropdownButton<String>(
                                  value: effectiveId,
                                  hint: Text(l10n.selectGroup),
                                  isExpanded: true,
                                  items: groups
                                      .map((g) => DropdownMenuItem(
                                            value: g.id,
                                            child: Text(g.name),
                                          ))
                                      .toList(),
                                  onChanged: _selectGroup,
                                  underline: const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ),
                          if (selectedGroupId != null) ...[
                            const SizedBox(width: 4),
                            Card(
                              color: cardColor,
                              child: IconButton(
                                icon: Icon(Icons.add_location_alt, color: iconColor),
                                onPressed: () => context.go(
                                    '/groups/$selectedGroupId/geofences/create'),
                              ),
                            ),
                          ],
                          const SizedBox(width: 4),
                          Card(
                            color: cardColor,
                            child: IconButton(
                              icon: Icon(Icons.group, color: iconColor),
                              onPressed: () => context.go('/groups'),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Card(
                            color: cardColor,
                            child: IconButton(
                              icon: Icon(Icons.settings, color: iconColor),
                              onPressed: () => context.go('/settings'),
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _myPosition != null
          ? FloatingActionButton(
              heroTag: 'myLocation',
              onPressed: _centerOnMe,
              child: const Icon(Icons.my_location),
            )
          : null,
    );
  }

  Widget _buildBasicMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _myPosition != null
            ? LatLng(_myPosition!.latitude, _myPosition!.longitude)
            : const LatLng(37.7749, -122.4194),
        initialZoom: 12,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.fence.app',
        ),
        _buildMyLocationMarker(),
      ],
    );
  }

  Widget _buildMap() {
    final groupId = ref.watch(selectedGroupIdProvider)!;
    final locationsAsync = ref.watch(groupLocationsProvider(groupId));
    final geofencesAsync = ref.watch(geofencesProvider(groupId));
    final presenceList = ref.watch(groupGeofencePresenceProvider(groupId));

    // Build a lookup: userId → list of geofence names they're in
    final userGeofenceNames = <String, List<String>>{};
    // Build a lookup: userId → all presences (for arrival info)
    final userPresences = <String, List<GeofencePresence>>{};
    for (final p in presenceList) {
      userGeofenceNames.putIfAbsent(p.userId, () => []).add(p.geofenceName);
      userPresences.putIfAbsent(p.userId, () => []).add(p);
    }

    // Geofence-only users: those with sharing_mode == "geofences"
    // Deduplicate by userId — show first geofence entry
    final geofenceOnlyUsers = <String, GeofencePresence>{};
    for (final p in presenceList) {
      if (p.sharingMode == 'geofences' &&
          p.geofenceLatitude != null &&
          p.geofenceLongitude != null &&
          !geofenceOnlyUsers.containsKey(p.userId)) {
        geofenceOnlyUsers[p.userId] = p;
      }
    }

    final focusUserId = ref.watch(mapFocusUserProvider);
    if (focusUserId != null) {
      ref.read(mapFocusUserProvider.notifier).state = null;
      final locations = locationsAsync.valueOrNull;
      MemberLocation? target;
      if (locations != null) {
        target = locations.cast<MemberLocation?>().firstWhere(
              (l) => l!.userId == focusUserId && l.latitude != null && l.longitude != null,
              orElse: () => null,
            );
      }
      if (target != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(LatLng(target!.latitude!, target.longitude!), 15);
        });
      } else if (geofenceOnlyUsers.containsKey(focusUserId)) {
        final p = geofenceOnlyUsers[focusUserId]!;
        if (p.geofenceLatitude != null && p.geofenceLongitude != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapController.move(LatLng(p.geofenceLatitude!, p.geofenceLongitude!), 15);
          });
        }
      }
    }

    final focusLatLng = ref.watch(mapFocusLatLngProvider);
    if (focusLatLng != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(mapFocusLatLngProvider.notifier).state = null;
        _mapController.move(LatLng(focusLatLng.lat, focusLatLng.lng), 15);
      });
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
            _buildGeofencePresenceMarkerLayer(geofenceOnlyUsers.values.toList()),
            _buildMyLocationMarker(),
          ],
        ),
        _buildSidebar(locationsAsync, geofenceOnlyUsers, userGeofenceNames, userPresences),
        _buildHistoryDrawer(),
      ],
    );
  }

  Widget _buildHistoryDrawer() {
    final historyUserId = ref.watch(historyDrawerUserIdProvider);
    if (historyUserId == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.15,
      maxChildSize: 0.8,
      builder: (sheetContext, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle + close button
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 16, right: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 32,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        ref.read(historyDrawerUserIdProvider.notifier).state =
                            null;
                      },
                      tooltip: l10n.close,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.history,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: HistoryEventList(
                  userId: historyUserId,
                  scrollController: scrollController,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMemberDetail(
    MemberLocation member,
    List<GeofencePresence>? presences,
  ) {
    final groupId = ref.read(selectedGroupIdProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MemberDetailSheet(
        userId: member.userId,
        displayName: member.displayName,
        updatedAt: member.updatedAt,
        presences: presences ?? [],
        groupId: groupId,
      ),
    );
  }

  void _showGeofenceMemberDetail(GeofencePresence presence) {
    final groupId = ref.read(selectedGroupIdProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MemberDetailSheet(
        userId: presence.userId,
        displayName: presence.displayName,
        updatedAt: null,
        presences: [presence],
        groupId: groupId,
      ),
    );
  }

  Widget _buildSidebar(
    AsyncValue<List<MemberLocation>> locationsAsync,
    Map<String, GeofencePresence> geofenceOnlyUsers,
    Map<String, List<String>> userGeofenceNames,
    Map<String, List<GeofencePresence>> userPresences,
  ) {
    return locationsAsync.when(
      data: (locations) {
        final hasEntries = locations.isNotEmpty || geofenceOnlyUsers.isNotEmpty;
        if (!hasEntries) return const SizedBox.shrink();

        final liveEntries = locations
            .map((l) {
          final geofences = userGeofenceNames[l.userId];
          final suffix = geofences != null && geofences.isNotEmpty
              ? ' @ ${geofences.first}'
              : '';
          return InkWell(
            onTap: () {
              _focusOnMember(l);
              _showMemberDetail(l, userPresences[l.userId]);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
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
                  Flexible(
                    child: Text(
                      '${l.displayName}$suffix - ${_timeAgo(l.updatedAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList();

        final geofenceEntries = geofenceOnlyUsers.values
            .map((p) {
          return InkWell(
            onTap: () {
              _focusOnPresence(p);
              _showGeofenceMemberDetail(p);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fence, size: 8, color: colorForUser(p.userId)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${p.displayName} @ ${p.geofenceName}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList();

        if (liveEntries.isEmpty && geofenceEntries.isEmpty) {
          return const SizedBox.shrink();
        }

        return Positioned(
          bottom: 16,
          left: 16,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [...liveEntries, ...geofenceEntries],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  MarkerLayer _buildGeofencePresenceMarkerLayer(List<GeofencePresence> presenceUsers) {
    final markers = presenceUsers
        .where((p) => p.geofenceLatitude != null && p.geofenceLongitude != null)
        .map((p) => Marker(
              point: LatLng(p.geofenceLatitude!, p.geofenceLongitude!),
              width: 60,
              height: 48,
              child: Opacity(
                opacity: 0.6,
                child: MemberMarker(
                  userId: p.userId,
                  displayName: p.displayName,
                  timeAgo: '@ ${p.geofenceName}',
                ),
              ),
            ))
        .toList();
    return MarkerLayer(markers: markers);
  }

  MarkerLayer _buildMarkerLayer(AsyncValue<List<MemberLocation>> locationsAsync) {
    final currentUserId = ref.watch(authProvider.select((s) => s.user?.id));
    final markers = locationsAsync.when(
      data: (locations) => locations
          .where((l) =>
              l.latitude != null &&
              l.longitude != null &&
              l.userId != currentUserId)
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
    } else {
      _showCreateGeofenceSheet(point, groupId);
    }
  }

  void _showCreateGeofenceSheet(LatLng point, String groupId) {
    final nameController = TextEditingController();
    final radiusController = TextEditingController(text: '200');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext);
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.createGeofence,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: l10n.name,
                    border: const OutlineInputBorder(),
                  ),
                  autofocus: true,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.nameIsRequired : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: radiusController,
                  decoration: InputDecoration(
                    labelText: l10n.radiusMeters,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    if (n == null || n <= 0) return l10n.enterPositiveNumber;
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final navigator = Navigator.of(sheetContext);
                    try {
                      await ref.read(apiClientProvider).createGeofence(groupId, {
                        'name': nameController.text.trim(),
                        'latitude': point.latitude,
                        'longitude': point.longitude,
                        'radius_meters':
                            double.parse(radiusController.text.trim()),
                      });
                      ref.invalidate(geofencesProvider(groupId));
                      navigator.pop();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.geofenceCreated)),
                        );
                      }
                    } on Exception catch (e) {
                      navigator.pop();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text(l10n.failedToCreateGeofence(e.toString()))),
                        );
                      }
                    }
                  },
                  child: Text(l10n.create),
                ),
              ],
            ),
          ),
        );
      },
    );
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
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
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
    final l10n = AppLocalizations.of(context);
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return l10n.timeAgoJustNow;
    if (diff.inMinutes < 60) return l10n.timeAgoMinutes(diff.inMinutes);
    if (diff.inHours < 24) return l10n.timeAgoHours(diff.inHours);
    return l10n.timeAgoDays(diff.inDays);
  }
}

class _MemberDetailSheet extends ConsumerWidget {
  final String userId;
  final String displayName;
  final DateTime? updatedAt;
  final List<GeofencePresence> presences;
  final String? groupId;

  const _MemberDetailSheet({
    required this.userId,
    required this.displayName,
    required this.updatedAt,
    required this.presences,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bgColor = colorForUser(userId);
    final textColor =
        bgColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    final historyAsync = ref.watch(historyProvider(userId));

    // Current location from presences
    final currentGeofences = presences
        .where((p) => p.geofenceLatitude != null)
        .toList();

    // Look up home geofence from group members
    String? homeGeofenceId;
    String? homeGeofenceName;
    if (groupId != null) {
      final membersAsync = ref.watch(groupMembersProvider(groupId!));
      membersAsync.whenData((members) {
        final member = members.where((m) => m.id == userId).firstOrNull;
        if (member != null) {
          homeGeofenceId = member.homeGeofenceId;
          homeGeofenceName = member.homeGeofenceName;
        }
      });
    }

    // Check if user is currently at home
    final isAtHome = homeGeofenceId != null &&
        currentGeofences.any((p) => p.geofenceId == homeGeofenceId);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: avatar + name + last updated
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    getInitials(displayName),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: theme.textTheme.titleLarge),
                      if (updatedAt != null)
                        Text(
                          '${l10n.lastUpdated} ${_timeAgo(updatedAt!, l10n)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Current location
            if (currentGeofences.isNotEmpty)
              ...currentGeofences.map((p) {
                final isHomeGeofence = p.geofenceId == homeGeofenceId;
                final label = isHomeGeofence
                    ? '${l10n.currentlyAtHome}: '
                    : '${l10n.currentLocation}: ';
                final icon = isHomeGeofence ? Icons.home : Icons.place;
                return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: InkWell(
                      onTap: groupId != null
                          ? () {
                              Navigator.pop(context);
                              context.go('/groups/$groupId/geofences/${p.geofenceId}');
                            }
                          : null,
                      child: Row(
                        children: [
                          Icon(icon, size: 18,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(label,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          Flexible(
                            child: Text(
                              p.geofenceName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
              }),

            // Home geofence (shown when not currently at home)
            if (!isAtHome && homeGeofenceId != null && homeGeofenceName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: InkWell(
                  onTap: groupId != null
                      ? () {
                          Navigator.pop(context);
                          context.go('/groups/$groupId/geofences/$homeGeofenceId');
                        }
                      : null,
                  child: Row(
                    children: [
                      Icon(Icons.home, size: 18,
                          color: theme.colorScheme.secondary),
                      const SizedBox(width: 8),
                      Text('${l10n.home}: ',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      Flexible(
                        child: Text(
                          homeGeofenceName!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // History: arrivals/departures
            historyAsync.when(
              data: (events) {
                if (events.isEmpty) {
                  return Text(l10n.noHistoryYet,
                      style: theme.textTheme.bodySmall);
                }
                // Combine enter+exit pairs into "arrived and spent" entries
                final displayItems = _combineEvents(events.take(20).toList());
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: displayItems.take(10).map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: InkWell(
                        onTap: groupId != null
                            ? () {
                                Navigator.pop(context);
                                context.go(
                                    '/groups/$groupId/geofences/${item.geofenceId}');
                              }
                            : null,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              item.icon,
                              size: 16,
                              color: item.iconColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _timeAgo(item.timestamp, l10n),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    if (item.duration != null)
                                      TextSpan(
                                        text: l10n.arrivedAndSpent(
                                            item.geofenceName,
                                            _formatDuration(item.duration!)),
                                        style: theme.textTheme.bodySmall,
                                      )
                                    else ...[
                                      TextSpan(
                                        text: item.isEntry
                                            ? '${l10n.arrivedAt} '
                                            : '${l10n.exited} ',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      TextSpan(
                                        text: item.geofenceName,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.primary,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  /// Combine enter/exit pairs for the same geofence into single "arrived and spent" items.
  /// Events are sorted desc (newest first). An "exited" followed by an "entered" for the
  /// same geofence means the user entered then later exited.
  static List<_HistoryDisplayItem> _combineEvents(List<GeofenceEvent> events) {
    final items = <_HistoryDisplayItem>[];
    final used = <int>{};

    for (var i = 0; i < events.length; i++) {
      if (used.contains(i)) continue;
      final e = events[i];

      if (e.event == 'exited') {
        // Look for a matching "entered" event for the same geofence (later in list = earlier in time)
        int? matchIdx;
        for (var j = i + 1; j < events.length; j++) {
          if (used.contains(j)) continue;
          if (events[j].geofenceId == e.geofenceId && events[j].event == 'entered') {
            matchIdx = j;
            break;
          }
        }
        if (matchIdx != null) {
          used.add(matchIdx);
          final entered = events[matchIdx];
          final duration = e.insertedAt.difference(entered.insertedAt);
          items.add(_HistoryDisplayItem(
            geofenceId: e.geofenceId,
            geofenceName: e.geofenceName,
            timestamp: entered.insertedAt,
            isEntry: true,
            duration: duration,
            icon: Icons.schedule,
            iconColor: Colors.blue[700]!,
          ));
        } else {
          items.add(_HistoryDisplayItem(
            geofenceId: e.geofenceId,
            geofenceName: e.geofenceName,
            timestamp: e.insertedAt,
            isEntry: false,
            icon: Icons.logout,
            iconColor: Colors.red[700]!,
          ));
        }
      } else {
        // "entered" without a prior exit — still there
        items.add(_HistoryDisplayItem(
          geofenceId: e.geofenceId,
          geofenceName: e.geofenceName,
          timestamp: e.insertedAt,
          isEntry: true,
          icon: Icons.login,
          iconColor: Colors.green[700]!,
        ));
      }
    }
    return items;
  }

  static String _formatDuration(Duration d) {
    if (d.inMinutes < 1) return '<1m';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    final hours = d.inHours;
    final mins = d.inMinutes % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  static String _timeAgo(DateTime dateTime, AppLocalizations l10n) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return l10n.timeAgoJustNow;
    if (diff.inMinutes < 60) return l10n.timeAgoMinutes(diff.inMinutes);
    if (diff.inHours < 24) return l10n.timeAgoHours(diff.inHours);
    return l10n.timeAgoDays(diff.inDays);
  }
}

class _HistoryDisplayItem {
  final String geofenceId;
  final String geofenceName;
  final DateTime timestamp;
  final bool isEntry;
  final Duration? duration;
  final IconData icon;
  final Color iconColor;

  const _HistoryDisplayItem({
    required this.geofenceId,
    required this.geofenceName,
    required this.timestamp,
    required this.isEntry,
    this.duration,
    required this.icon,
    required this.iconColor,
  });
}

class _JoinSheetBody extends ConsumerStatefulWidget {
  const _JoinSheetBody({required this.scrollController});
  final ScrollController scrollController;

  @override
  ConsumerState<_JoinSheetBody> createState() => _JoinSheetBodyState();
}

class _JoinSheetBodyState extends ConsumerState<_JoinSheetBody> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeController.text.trim().toUpperCase();
    final name = _nameController.text.trim();
    if (code.isEmpty || name.isEmpty) return;

    setState(() => _loading = true);
    await ref.read(authProvider.notifier).joinAsAnonymous(code, name);
    if (mounted) {
      final authState = ref.read(authProvider);
      if (authState.status == AuthStatus.authenticated) {
        Navigator.of(context).pop();
      } else {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final l10n = AppLocalizations.of(context);

    String? errorText;
    if (authState.errorKey == AuthErrorKey.invalidInviteCode) {
      errorText = l10n.errorInvalidInviteCode;
    } else if (authState.errorKey == AuthErrorKey.inviteCodeExpired) {
      errorText = l10n.errorInviteCodeExpired;
    } else if (authState.errorKey == AuthErrorKey.anonymousJoinFailed) {
      errorText = l10n.anonymousJoinFailed;
    }

    return ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      children: [
        Center(
          child: Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Mi Pueblo',
          style: Theme.of(context).textTheme.headlineLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.appSubtitle,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _codeController,
          decoration: InputDecoration(
            labelText: l10n.groupCodePrompt,
            border: const OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [_UpperCaseTextFormatter()],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: l10n.yourName,
            border: const OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _join(),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 16),
          Text(
            errorText,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _loading ? null : _join,
          child: _loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.joinButton),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () {
            final router = GoRouter.of(context);
            Navigator.of(context).pop();
            router.go('/auth/create');
          },
          child: Text(l10n.createAGroup),
        ),
      ],
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
