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
import 'package:fence/providers/location_manager_provider.dart';
import 'package:fence/providers/websocket_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    ref.watch(websocketManagerProvider);
    ref.watch(geofenceSyncManagerProvider);
    ref.watch(geofenceNotificationProvider);
    ref.watch(locationManagerProvider);
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'Fence',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
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
