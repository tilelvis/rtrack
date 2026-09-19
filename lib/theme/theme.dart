import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design system for Loan Tracker.
///
/// Supports BOTH dark (default, brand identity) and light modes.
/// Mode is selected at runtime via [AppTheme.dark] / [AppTheme.light].
///
/// All brand colors (primary, accent, danger, etc.) are `static const`
/// so they can be used inside `const` widget constructors.
///
/// Mode-dependent tokens (bg, surface, text) are NOT const — they are
/// resolved at runtime via [AppTheme.of] which returns a [ThemeTokens]
/// object for the current brightness. Widgets that need mode-dependent
/// colors should NOT use `const` for those styles.
class AppTheme {
  // ---- Brand colors (mode-independent, const) ----
  // In light mode, primary uses `primaryLight` (softer). In dark mode,
  // primary uses `primaryDark` (neon). Both are const so they can be
  // used in const widget constructors.
  static const Color primary = Color(0xFF1FAE0D);   // printable green
  static const Color primaryDark = Color(0xFF39FF14); // neon green (dark mode)
  static const Color primaryLight = Color(0xFF1FAE0D); // soft green (light mode)
  static const Color accent = Color(0xFF00A0B0);    // teal/cyan
  static const Color accentDark = Color(0xFF00E5FF); // neon cyan
  static const Color accentLight = Color(0xFF00A0B0); // soft teal
  static const Color magenta = Color(0xFFFF2BD6);
  static const Color warning = Color(0xFFFFB020);
  static const Color danger = Color(0xFFFF3B3B);

  // ---- Dark mode tokens (const) ----
  static const Color darkBg = Color(0xFF0A0E14);
  static const Color darkSurface = Color(0xFF121821);
  static const Color darkSurfaceAlt = Color(0xFF1A2230);
  static const Color darkTextPrimary = Color(0xFFF5F7FA);
  static const Color darkTextSecondary = Color(0xFF9BA8C0);
  static const Color darkBorder = Color(0xFF243044);

  // ---- Light mode tokens (const) ----
  static const Color lightBg = Color(0xFFF5F7FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFEFF3F8);
  static const Color lightTextPrimary = Color(0xFF0A0E14);
  static const Color lightTextSecondary = Color(0xFF5A6877);
  static const Color lightBorder = Color(0xFFD8DFE8);

  // ---- Backward-compatibility getters ----
  // These return the DARK mode tokens by default. Widgets that were
  // written before light mode support was added will continue to work
  // (they'll use dark colors). New widgets that need to respect light
  // mode should use [AppTheme.of(context)] instead.
  //
  // IMPORTANT: these are NOT const, so they can't be used inside
  // `const` widget constructors. If a widget needs const colors, use
  // the explicit `darkBg` / `lightBg` / etc. constants.
  static Color get bg => _current.bg;
  static Color get surface => _current.surface;
  static Color get surfaceAlt => _current.surfaceAlt;
  static Color get textPrimary => _current.textPrimary;
  static Color get textSecondary => _current.textSecondary;
  static Color get border => _current.border;

  static ThemeTokens _current = ThemeTokens(
    bg: darkBg,
    surface: darkSurface,
    surfaceAlt: darkSurfaceAlt,
    textPrimary: darkTextPrimary,
    textSecondary: darkTextSecondary,
    border: darkBorder,
  );

  /// Resolve tokens for the given brightness. Call from MaterialApp's
  /// builder or from any widget that needs to switch on brightness.
  static ThemeTokens of(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    return brightness == Brightness.light ? lightTokens : darkTokens;
  }

  static const ThemeTokens darkTokens = ThemeTokens(
    bg: darkBg,
    surface: darkSurface,
    surfaceAlt: darkSurfaceAlt,
    textPrimary: darkTextPrimary,
    textSecondary: darkTextSecondary,
    border: darkBorder,
  );

  static const ThemeTokens lightTokens = ThemeTokens(
    bg: lightBg,
    surface: lightSurface,
    surfaceAlt: lightSurfaceAlt,
    textPrimary: lightTextPrimary,
    textSecondary: lightTextSecondary,
    border: lightBorder,
  );

  /// Update the static `_current` so legacy `AppTheme.bg` style getters
  /// return the correct mode's tokens. Called from MaterialApp.builder.
  static void _resolve(Brightness brightness) {
    _current = brightness == Brightness.light ? lightTokens : darkTokens;
  }

  /// Build a ThemeData for the requested brightness.
  static ThemeData forBrightness(Brightness brightness) {
    _resolve(brightness);

    final isLight = brightness == Brightness.light;
    final base = ThemeData(useMaterial3: true, brightness: brightness);

    // In light mode, use the printable (softer) greens/cyans.
    // In dark mode, use the neon variants.
    final primaryColor = isLight ? primaryLight : primaryDark;
    final accentColor = isLight ? accentLight : accentDark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: brightness,
      primary: primaryColor,
      secondary: accentColor,
      surface: _current.surface,
      error: danger,
      onSurface: _current.textPrimary,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _current.bg,
      canvasColor: _current.bg,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          color: _current.textPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.inter(
          color: _current.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: GoogleFonts.inter(
          color: _current.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.inter(color: _current.textPrimary),
        bodyMedium: GoogleFonts.inter(color: _current.textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _current.bg,
        foregroundColor: _current.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: _current.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: _current.surface,
        elevation: isLight ? 1 : 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _current.border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _current.surfaceAlt,
        hintStyle: TextStyle(color: _current.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _current.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _current.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: isLight ? Colors.white : const Color(0xFF001100),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentColor,
          side: BorderSide(color: accentColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: isLight ? Colors.white : const Color(0xFF001100),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _current.surfaceAlt,
        labelStyle: TextStyle(color: _current.textPrimary),
        side: BorderSide(color: _current.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dividerColor: _current.border,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _current.surface,
        indicatorColor: primaryColor.withOpacity(0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? primaryColor : _current.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? primaryColor : _current.textSecondary,
            size: 22,
          );
        }),
      ),
    );
  }

  static ThemeData get dark => forBrightness(Brightness.dark);
  static ThemeData get light => forBrightness(Brightness.light);
}

/// Resolved color tokens for a specific brightness.
///
/// All fields are `final` (not `const`-named with underscore prefix)
/// so the class can be const-constructed.
@immutable
class ThemeTokens {
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;

  const ThemeTokens({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
  });
}
