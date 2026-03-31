import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/providers/auth_provider.dart';
import 'package:fence/services/location_service.dart';

final locationManagerProvider = Provider<void>((ref) {
  final auth = ref.watch(authProvider);
  final locationService = ref.read(locationServiceProvider);

  if (auth.status != AuthStatus.authenticated) {
    locationService.stopTracking();
    return;
  }

  var disposed = false;

  locationService.requestPermissions().then((status) {
    if (!disposed && status == PermissionStatus.granted) {
      locationService.startTracking();
    }
  });

  ref.onDispose(() {
    disposed = true;
    locationService.stopTracking();
    locationService.dispose();
  });
});
