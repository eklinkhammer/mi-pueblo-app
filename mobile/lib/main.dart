import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/firebase_options.dart';
import 'package:fence/l10n/app_localizations.dart';
import 'package:fence/providers/geofence_notification_provider.dart';
import 'package:fence/providers/geofence_sync_provider.dart';
import 'package:fence/providers/locale_provider.dart';
import 'package:fence/providers/theme_color_provider.dart';
import 'package:fence/providers/location_manager_provider.dart';
import 'package:fence/providers/websocket_provider.dart';
import 'package:fence/providers/auth_provider.dart';
import 'package:fence/router.dart';
import 'package:fence/services/deep_link_service.dart';
import 'package:fence/services/headless_task.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await bg.BackgroundGeolocation.registerHeadlessTask(headlessTask);
  runApp(const ProviderScope(child: FenceApp()));
}

class FenceApp extends ConsumerStatefulWidget {
  const FenceApp({super.key});

  @override
  ConsumerState<FenceApp> createState() => _FenceAppState();
}

class _FenceAppState extends ConsumerState<FenceApp> {
  final _deepLinkService = DeepLinkService();
  StreamSubscription<String>? _linkSub;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    // Cold-start link
    final code = await _deepLinkService.getInitialInviteCode();
    if (code != null) {
      ref.read(pendingInviteCodeProvider.notifier).state = code;
    }

    // Warm-resume links
    _linkSub = _deepLinkService.onInviteCode.listen((code) {
      ref.read(pendingInviteCodeProvider.notifier).state = code;
    });
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  void _consumePendingCode(String code) {
    final authStatus = ref.read(authProvider).status;
    if (authStatus == AuthStatus.unknown) return; // wait for auth
    ref.read(pendingInviteCodeProvider.notifier).state = null;
    final router = ref.read(routerProvider);
    if (authStatus == AuthStatus.authenticated) {
      router.go('/groups/join?code=$code');
    } else {
      router.go('/auth/join?code=$code');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Handle warm-resume deep links
    ref.listen<String?>(pendingInviteCodeProvider, (prev, next) {
      if (next != null) {
        _consumePendingCode(next);
      }
    });

    // Handle cold-start: auth resolves after pending code was set
    ref.listen<AuthStatus>(
      authProvider.select((s) => s.status),
      (prev, next) {
        if (prev == AuthStatus.unknown && next != AuthStatus.unknown) {
          final code = ref.read(pendingInviteCodeProvider);
          if (code != null) _consumePendingCode(code);
        }
      },
    );

    ref.watch(websocketManagerProvider);
    ref.watch(geofenceSyncManagerProvider);
    ref.watch(geofenceNotificationProvider);
    ref.watch(locationManagerProvider);
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    final themeColor = ref.watch(themeColorProvider);

    return MaterialApp.router(
      title: 'Fence',
      theme: ThemeData(
        colorSchemeSeed: themeColor,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: themeColor,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
