import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;

@pragma('vm:entry-point')
void headlessTask(bg.HeadlessEvent headlessEvent) {
  // No-op stub for initial migration.
  // Locations queue in the plugin's SQLite DB and sync on next foreground launch.
}
