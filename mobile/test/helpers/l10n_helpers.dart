import 'package:flutter/material.dart';
import 'package:fence/l10n/app_localizations.dart';

/// Wraps a widget in a MaterialApp with localization delegates for testing.
Widget localizedApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}
