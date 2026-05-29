import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kColorKey = 'theme_color';

const themeColorOptions = <String, Color>{
  'Blue': Color(0xFF1565C0),
  'Green': Color(0xFF2E7D32),
  'Purple': Color(0xFF6A1B9A),
  'Orange': Color(0xFFE65100),
  'Red': Color(0xFFC62828),
  'Teal': Color(0xFF00695C),
  'Pink': Color(0xFFAD1457),
  'Indigo': Color(0xFF283593),
};

class ThemeColorNotifier extends StateNotifier<Color> {
  ThemeColorNotifier() : super(Colors.blue) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kColorKey);
    if (name != null && themeColorOptions.containsKey(name)) {
      state = themeColorOptions[name]!;
    }
  }

  Future<void> setColor(String name) async {
    if (themeColorOptions.containsKey(name)) {
      state = themeColorOptions[name]!;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kColorKey, name);
    }
  }
}

final themeColorProvider =
    StateNotifierProvider<ThemeColorNotifier, Color>((ref) {
  return ThemeColorNotifier();
});
