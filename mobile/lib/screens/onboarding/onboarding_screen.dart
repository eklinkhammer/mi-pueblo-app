import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:fence/utils/user_colors.dart';
import 'package:fence/widgets/member_marker.dart';

// Geofence locations
const _primosHouse = LatLng(36.19, -115.10);
const _abuelasHouse = LatLng(36.12, -115.17);
const _geofenceRadius = 800.0; // meters

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _mapReady = false;
  bool _peopleVisible = false;

  static const _items = [
    'Trying to find the most convenient place for all the cousins?',
    'Wish you knew when the party actually gets going, and how much to bring?',
    'Tired of guessing if that one uncle is actually on his way?',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onMapReady() async {
    if (_mapReady) return;
    setState(() => _mapReady = true);

    // Wait 2 seconds, then show people + geofences
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _peopleVisible = true);

    // Wait 1 more second, then start text animation
    await Future<void>.delayed(const Duration(seconds: 1));
    if (mounted) await _controller.forward();
  }

  Widget _buildAvatarGroup(List<(String userId, String name)> members) {
    const size = 28.0;
    const overlap = 10.0;
    return SizedBox(
      width: size + (members.length - 1) * (size - overlap),
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < members.length; i++)
            Positioned(
              left: i * (size - overlap),
              child: _buildAvatar(members[i].$1, members[i].$2, size),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String userId, String name, double size) {
    final bgColor = colorForUser(userId);
    final textColor =
        bgColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        getInitials(name),
        style: TextStyle(
          color: textColor,
          fontSize: size * 0.38,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  double _itemProgress(int index, double overall) {
    final start = index / _items.length;
    final end = (index + 1) / _items.length;
    return ((overall - start) / (end - start)).clamp(0.0, 1.0);
  }

  Widget _buildItem(ThemeData theme, int index, String text, double progress) {
    if (progress <= 0) return const SizedBox(height: 40);

    return Opacity(
      opacity: progress.clamp(0.0, 1.0),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 2,
                  ),
                ),
                Text(
                  '${index + 1}',
                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: theme.textTheme.bodyLarge?.copyWith(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // Map background
          FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(36.17, -115.14),
              initialZoom: 11,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
              onMapReady: _onMapReady,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.fence.app',
              ),
              if (_peopleVisible) ...[
                // Geofence circles
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _primosHouse,
                      radius: _geofenceRadius,
                      useRadiusInMeter: true,
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderColor: Colors.blue.withValues(alpha: 0.5),
                      borderStrokeWidth: 2,
                    ),
                    CircleMarker(
                      point: _abuelasHouse,
                      radius: _geofenceRadius,
                      useRadiusInMeter: true,
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderColor: Colors.blue.withValues(alpha: 0.5),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
                // Geofence labels with occupant lists
                MarkerLayer(
                  markers: [
                    Marker(
                      point: const LatLng(36.215, -115.10),
                      width: 140,
                      height: 44,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Primo's House",
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Primo, Tía',
                                style: TextStyle(fontSize: 10, color: Colors.black87),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Marker(
                      point: const LatLng(36.145, -115.17),
                      width: 140,
                      height: 44,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Abuela's House",
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Abuela',
                                style: TextStyle(fontSize: 10, color: Colors.black87),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Overlapping avatar groups at each geofence
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _primosHouse,
                      width: 60,
                      height: 30,
                      child: _buildAvatarGroup([
                        ('onboarding-primo', 'Primo'),
                        ('onboarding-tia', 'Tía'),
                      ]),
                    ),
                    Marker(
                      point: _abuelasHouse,
                      width: 40,
                      height: 30,
                      child: _buildAvatarGroup([
                        ('onboarding-abuela', 'Abuela'),
                      ]),
                    ),
                  ],
                ),
                // Standalone person not in a geofence
                const MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(36.16, -115.05),
                      width: 60,
                      height: 48,
                      child: MemberMarker(
                        userId: 'onboarding-carlos',
                        displayName: 'Carlos',
                        timeAgo: '1m ago',
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          // Semi-transparent overlay for readability
          Container(color: Colors.white.withValues(alpha: 0.93)),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top quarter: title + subtitle
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          'Mi Pueblo',
                          style: theme.textTheme.headlineLarge?.copyWith(color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text.rich(
                          const TextSpan(
                            children: [
                              TextSpan(
                                  text: 'Coordinate and share with the '),
                              TextSpan(
                                text: 'whole',
                                style:
                                    TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: ' family'),
                            ],
                          ),
                          style: theme.textTheme.bodyLarge?.copyWith(color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  // Middle spacer
                  const Expanded(flex: 1, child: SizedBox.shrink()),
                  // Bottom third: animated sentences + button
                  Expanded(
                    flex: 1,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final overall = _controller.value;
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < _items.length; i++) ...[
                              if (i > 0) const SizedBox(height: 16),
                              _buildItem(theme, i, _items[i],
                                  _itemProgress(i, overall)),
                            ],
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: () {
                                context.go('/onboarding/permissions');
                              },
                              child: const Text('Get Started'),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
