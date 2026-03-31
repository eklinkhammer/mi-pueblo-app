import 'package:flutter/material.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/l10n/app_localizations.dart';
import 'package:fence/providers/geofence_sync_provider.dart';
import 'package:fence/providers/locale_provider.dart';
import 'package:fence/providers/websocket_provider.dart';
import 'package:fence/router.dart';
import 'package:fence/services/headless_task.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  bg.BackgroundGeolocation.registerHeadlessTask(headlessTask);
  runApp(const ProviderScope(child: FenceApp()));
}

class FenceApp extends ConsumerWidget {
  const FenceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(websocketManagerProvider);
    ref.watch(geofenceSyncManagerProvider);
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
