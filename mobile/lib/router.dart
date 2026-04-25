import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fence/providers/auth_provider.dart';
import 'package:fence/providers/onboarding_provider.dart';
import 'package:fence/screens/auth/anonymous_create_screen.dart';
import 'package:fence/screens/auth/anonymous_join_screen.dart';
import 'package:fence/screens/auth/login_screen.dart';
import 'package:fence/screens/auth/register_screen.dart';
import 'package:fence/screens/onboarding/onboarding_screen.dart';
import 'package:fence/screens/onboarding/permissions_screen.dart';
import 'package:fence/screens/map/map_screen.dart';
import 'package:fence/screens/groups/group_list_screen.dart';
import 'package:fence/screens/groups/group_detail_screen.dart';
import 'package:fence/screens/groups/group_create_screen.dart';
import 'package:fence/screens/groups/join_group_screen.dart';
import 'package:fence/screens/geofences/geofence_create_screen.dart';
import 'package:fence/screens/geofences/geofence_detail_screen.dart';
import 'package:fence/screens/groups/group_notification_settings_screen.dart';
import 'package:fence/screens/settings/settings_screen.dart';
import 'package:fence/services/deep_link_service.dart';
import 'package:fence/widgets/shell_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authStatus = ref.watch(authProvider.select((s) => s.status));
  final onboardingCompleted = ref.watch(onboardingProvider);
  final pendingCode = ref.watch(pendingInviteCodeProvider);

  return GoRouter(
    initialLocation: '/map',
    redirect: (context, state) {
      final isOnboarding = state.matchedLocation.startsWith('/onboarding');

      if (!onboardingCompleted && !isOnboarding) return '/onboarding';
      if (onboardingCompleted && isOnboarding) return '/map';

      final isAuth = authStatus == AuthStatus.authenticated;
      final isAuthRoute =
          state.matchedLocation.startsWith('/auth') || isOnboarding;

      if (authStatus == AuthStatus.unknown) return null;

      // Deep link: redirect to join screen with pending invite code
      if (pendingCode != null) {
        if (isAuth) {
          return '/groups/join?code=$pendingCode';
        } else {
          return '/auth/join?code=$pendingCode';
        }
      }

      final isMapRoute = state.matchedLocation == '/map';
      if (!isAuth && !isAuthRoute && !isMapRoute) return '/auth/create';
      if (isAuth && isAuthRoute) return '/map';
      return null;
    },
    routes: [
      // Onboarding routes
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
        routes: [
          GoRoute(
            path: 'permissions',
            builder: (context, state) => const PermissionsScreen(),
          ),
        ],
      ),

      // Auth routes
      GoRoute(
        path: '/auth/create',
        builder: (context, state) => const AnonymousCreateScreen(),
      ),
      GoRoute(
        path: '/auth/join',
        builder: (context, state) => AnonymousJoinScreen(
          initialCode: state.uri.queryParameters['code'],
        ),
      ),
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // Main app with bottom nav
      ShellRoute(
        builder: (context, state, child) =>
            ShellScaffold(child: child),
        routes: [
          GoRoute(
            path: '/map',
            builder: (context, state) => const MapScreen(),
          ),
          GoRoute(
            path: '/groups',
            builder: (context, state) => const GroupListScreen(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) => const GroupCreateScreen(),
              ),
              GoRoute(
                path: 'join',
                builder: (context, state) => JoinGroupScreen(
                  initialCode: state.uri.queryParameters['code'],
                ),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    GroupDetailScreen(groupId: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'notification-settings',
                    builder: (context, state) =>
                        GroupNotificationSettingsScreen(
                            groupId: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'geofences/create',
                    builder: (context, state) => GeofenceCreateScreen(
                        groupId: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'geofences/:fid',
                    builder: (context, state) => GeofenceDetailScreen(
                      groupId: state.pathParameters['id']!,
                      geofenceId: state.pathParameters['fid']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
