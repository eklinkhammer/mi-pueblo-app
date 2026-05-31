import 'package:fence/config.dart';

String? fullAvatarUrl(String? avatarUrl) {
  if (avatarUrl == null) return null;
  // Strip /api/v1 from the base URL to get the server root
  final base = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/api/v\d+$'), '');
  return '$base$avatarUrl';
}
