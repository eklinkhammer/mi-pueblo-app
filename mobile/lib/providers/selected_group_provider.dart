import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedGroupIdProvider = StateProvider<String?>((ref) => null);

final mapFocusUserProvider = StateProvider<String?>((ref) => null);

final mapFocusLatLngProvider = StateProvider<({double lat, double lng})?>((ref) => null);
