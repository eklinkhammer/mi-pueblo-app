import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fence/providers/onboarding_provider.dart';

const _privacyPolicyUrl = 'https://mipueblo.app/privacy';
const _termsOfServiceUrl = 'https://mipueblo.app/terms';

class PermissionsScreen extends ConsumerWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodyMedium!;
    final linkStyle = bodyStyle.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
    );
    final headingStyle = theme.textTheme.titleMedium!;
    final boldStyle = bodyStyle.copyWith(fontWeight: FontWeight.bold);

    return Scaffold(
      body: Stack(
        children: [
          // Static map background (same setup as onboarding, no markers)
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(36.17, -115.14),
              initialZoom: 11,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.fence.app',
              ),
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
                  Text(
                    'Mi Pueblo',
                    style: theme.textTheme.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('What we use', style: headingStyle),
                          const SizedBox(height: 8),
                          Text(
                            'Mi Pueblo uses your phone\u2019s location to '
                            'share with your groups.',
                            style: bodyStyle,
                          ),
                          const SizedBox(height: 20),
                          Text('You remain in control', style: headingStyle),
                          const SizedBox(height: 8),
                          Text(
                            'You have to explicitly share your location with '
                            'every new addition to any group, and you can stop '
                            'sharing your location with any individual at any '
                            'time.',
                            style: bodyStyle,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Mi Pueblo does not use your data for anything '
                            'other than sharing with your groups, and you can '
                            'request data deletion at any time.',
                            style: bodyStyle,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your data will never be sold or stored.',
                            style: boldStyle,
                          ),
                          const SizedBox(height: 20),
                          Text('Permissions required', style: headingStyle),
                          const SizedBox(height: 8),
                          Text(
                            'Location is used only while the app is active or '
                            'with your background permission. You can change '
                            'permissions at any time in your device settings.',
                            style: bodyStyle,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This app should only be used with ongoing '
                            'consent of both parties sharing location.',
                            style: boldStyle,
                          ),
                          const SizedBox(height: 20),
                          Text('Terms of Use', style: headingStyle),
                          const SizedBox(height: 8),
                          Text.rich(
                            TextSpan(
                              style: bodyStyle,
                              children: [
                                const TextSpan(
                                  text: 'By continuing, you agree to our ',
                                ),
                                TextSpan(
                                  text: 'Terms of Service',
                                  style: linkStyle,
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () => launchUrl(
                                          Uri.parse(_termsOfServiceUrl),
                                          mode: LaunchMode.externalApplication,
                                        ),
                                ),
                                const TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: linkStyle,
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () => launchUrl(
                                          Uri.parse(_privacyPolicyUrl),
                                          mode: LaunchMode.externalApplication,
                                        ),
                                ),
                                const TextSpan(text: '.'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      ref
                          .read(onboardingProvider.notifier)
                          .completeOnboarding();
                      context.go('/auth/create');
                    },
                    child: const Text('Continue'),
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
