import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fence/providers/auth_provider.dart';
import 'package:fence/screens/auth/login_screen.dart';
import 'package:fence/screens/auth/register_screen.dart';
import 'package:fence/screens/map/map_screen.dart';
import 'package:fence/screens/groups/group_list_screen.dart';
import 'package:fence/screens/groups/group_detail_screen.dart';
import 'package:fence/screens/groups/group_create_screen.dart';
import 'package:fence/screens/groups/join_group_screen.dart';
import 'package:fence/screens/geofences/geofence_create_screen.dart';
import 'package:fence/screens/geofences/geofence_detail_screen.dart';
import 'package:fence/screens/groups/group_notification_settings_screen.dart';
import 'package:fence/screens/groups/group_visibility_screen.dart';
import 'package:fence/screens/settings/settings_screen.dart';
import 'package:fence/widgets/shell_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/map',
    redirect: (context, state) {
      final isAuth = authState.status == AuthStatus.authenticated;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');

      if (authState.status == AuthStatus.unknown) return null;
      if (!isAuth && !isAuthRoute) return '/auth/login';
      if (isAuth && isAuthRoute) return '/map';
      return null;
    },
    routes: [
      // Auth routes
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
                builder: (context, state) => const JoinGroupScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    GroupDetailScreen(groupId: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'visibility',
                    builder: (context, state) =>
                        GroupVisibilityScreen(
                            groupId: state.pathParameters['id']!),
                  ),
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
