import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mode selector for the app theme.
enum ThemeMode { system, light, dark }

extension ThemeModeLabel on ThemeMode {
  String get label {
    switch (this) {
      case ThemeMode.system:
        return 'System default';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  String get prefKey {
    switch (this) {
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
    }
  }

  static ThemeMode fromPrefKey(String? key) {
    switch (key) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}

/// App-wide theme provider. Reads the saved preference on startup and
/// exposes a [Brightness] that widgets can use to pick color variants.
class ThemeProvider extends ChangeNotifier {
  static const _prefKey = 'app_theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// The effective brightness — resolves `system` against the platform.
  Brightness brightnessFor(BuildContext context) {
    switch (_mode) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return MediaQuery.platformBrightnessOf(context);
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = ThemeModeLabel.fromPrefKey(prefs.getString(_prefKey));
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, mode.prefKey);
  }
}
