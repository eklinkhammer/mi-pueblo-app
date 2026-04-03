import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:fence/providers/onboarding_provider.dart';
import 'package:fence/widgets/member_marker.dart';

// Geofence locations
const _primosHouse = LatLng(36.19, -115.10);
const _abuelasHouse = LatLng(36.12, -115.17);
const _geofenceRadius = 800.0; // meters

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _mapReady = false;
  bool _peopleVisible = false;

  static const _items = [
    'Want to let your family know when you\u2019re hosting?',
    'Tired of always arriving too late for the good tamales?',
    'Looking to coordinate with your cousins?',
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
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: theme.textTheme.bodyLarge),
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
                // Geofence labels (offset below geofence edge)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: const LatLng(36.215, -115.10),
                      width: 120,
                      height: 24,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "Primo's House",
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    Marker(
                      point: const LatLng(36.145, -115.17),
                      width: 120,
                      height: 24,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "Abuela's House",
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // People markers
                const MarkerLayer(
                  markers: [
                    // Primo at Primo's House
                    Marker(
                      point: LatLng(36.19, -115.112),
                      width: 60,
                      height: 48,
                      child: MemberMarker(
                        userId: 'onboarding-primo',
                        displayName: 'Primo',
                        timeAgo: '5m ago',
                      ),
                    ),
                    // Tía at Primo's House
                    Marker(
                      point: LatLng(36.19, -115.088),
                      width: 60,
                      height: 48,
                      child: MemberMarker(
                        userId: 'onboarding-tia',
                        displayName: 'Tía',
                        timeAgo: '3m ago',
                      ),
                    ),
                    // Abuela at Abuela's House
                    Marker(
                      point: LatLng(36.121, -115.168),
                      width: 60,
                      height: 48,
                      child: MemberMarker(
                        userId: 'onboarding-abuela',
                        displayName: 'Abuela',
                        timeAgo: '2m ago',
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          // Semi-transparent overlay for readability
          Container(color: Colors.white.withValues(alpha: 0.55)),
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
                          style: theme.textTheme.headlineLarge,
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
                          style: theme.textTheme.bodyLarge,
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
                                ref
                                    .read(onboardingProvider.notifier)
                                    .completeOnboarding();
                                context.go('/auth/login');
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
