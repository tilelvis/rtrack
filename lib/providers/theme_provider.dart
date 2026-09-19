import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mode selector for the app theme.
///
/// Renamed from `ThemeMode` to `AppThemeMode` to avoid clashing with
/// Flutter's own `ThemeMode` enum (which is what MaterialApp.themeMode
/// expects). We convert between the two in main.dart.
enum AppThemeMode { system, light, dark }

extension AppThemeModeLabel on AppThemeMode {
  String get label {
    switch (this) {
      case AppThemeMode.system:
        return 'System default';
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
    }
  }

  String get prefKey {
    switch (this) {
      case AppThemeMode.system:
        return 'system';
      case AppThemeMode.light:
        return 'light';
      case AppThemeMode.dark:
        return 'dark';
    }
  }

  static AppThemeMode fromPrefKey(String? key) {
    switch (key) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      case 'system':
      default:
        return AppThemeMode.system;
    }
  }
}

/// App-wide theme provider. Reads the saved preference on startup and
/// exposes a [Brightness] that widgets can use to pick color variants.
class ThemeProvider extends ChangeNotifier {
  static const _prefKey = 'app_theme_mode';

  AppThemeMode _mode = AppThemeMode.system;
  AppThemeMode get mode => _mode;

  /// The effective brightness — resolves `system` against the platform.
  Brightness brightnessFor(BuildContext context) {
    switch (_mode) {
      case AppThemeMode.light:
        return Brightness.light;
      case AppThemeMode.dark:
        return Brightness.dark;
      case AppThemeMode.system:
        return MediaQuery.platformBrightnessOf(context);
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = AppThemeModeLabel.fromPrefKey(prefs.getString(_prefKey));
    notifyListeners();
  }

  Future<void> setMode(AppThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, mode.prefKey);
  }
}
