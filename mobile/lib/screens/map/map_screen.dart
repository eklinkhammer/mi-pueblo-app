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
    final isAuth =
        ref.watch(authProvider.select((s) => s.status == AuthStatus.authenticated));

    if (!isAuth) return _buildAnonymousView(context);
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
      appBar: AppBar(
        title: Text(l10n.map),
        actions: [
          groupsAsync.when(
            data: (groups) {
              final effectiveId = (selectedGroupId != null &&
                      groups.any((g) => g.id == selectedGroupId))
                  ? selectedGroupId
                  : null;
              if (effectiveId != selectedGroupId) {
                _didAutoSelect = false;
              }
              return DropdownButton<String>(
                value: effectiveId,
                hint: Text(l10n.selectGroup),
                items: groups
                    .map((g) => DropdownMenuItem(
                          value: g.id,
                          child: Text(g.name),
                        ))
                    .toList(),
                onChanged: _selectGroup,
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: selectedGroupId == null
          ? Center(child: Text(l10n.selectGroupToViewMap))
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
                  label: Text(l10n.addGeofence),
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
    final presenceList = ref.watch(groupGeofencePresenceProvider(groupId));

    // Build a lookup: userId → list of geofence names they're in
    final userGeofenceNames = <String, List<String>>{};
    for (final p in presenceList) {
      userGeofenceNames.putIfAbsent(p.userId, () => []).add(p.geofenceName);
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
        _buildSidebar(locationsAsync, geofenceOnlyUsers, userGeofenceNames),
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

  Widget _buildSidebar(
    AsyncValue<List<MemberLocation>> locationsAsync,
    Map<String, GeofencePresence> geofenceOnlyUsers,
    Map<String, List<String>> userGeofenceNames,
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
            onTap: () => _focusOnMember(l),
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
            onTap: () => _focusOnPresence(p),
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
