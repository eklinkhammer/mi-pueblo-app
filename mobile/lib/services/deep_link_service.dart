import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds a pending invite code from a deep link until consumed by a screen.
final pendingInviteCodeProvider = StateProvider<String?>((ref) => null);

class DeepLinkService {
  DeepLinkService() : _appLinks = AppLinks();

  final AppLinks _appLinks;

  /// Check for an initial (cold-start) link and return the invite code if any.
  Future<String?> getInitialInviteCode() async {
    final uri = await _appLinks.getInitialLink();
    if (uri == null) return null;
    return extractInviteCode(uri);
  }

  /// Stream of invite codes from links received while the app is running.
  Stream<String> get onInviteCode =>
      _appLinks.uriLinkStream.map(extractInviteCode).where((c) => c != null).cast<String>();

  /// Parses both `fence://join/CODE` and `https://fence.app/join/CODE`.
  static String? extractInviteCode(Uri uri) {
    // fence://join/CODE  →  host="join", pathSegments=["CODE"]
    if (uri.scheme == 'fence' && uri.host == 'join') {
      if (uri.pathSegments.isNotEmpty) return uri.pathSegments.first;
      return null;
    }

    // https://fence.app/join/CODE  →  pathSegments=["join", "CODE"]
    if (uri.host == 'fence.app' && uri.pathSegments.length >= 2 && uri.pathSegments.first == 'join') {
      return uri.pathSegments[1];
    }

    return null;
  }
}
