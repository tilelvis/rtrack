import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design system for Loan Tracker.
///
/// Supports BOTH dark (default, brand identity) and light modes.
/// Mode is selected at runtime via [AppTheme.dark] / [AppTheme.light].
///
/// Color tokens are kept as semantic constants so widgets can reference
/// brand colors (e.g. `AppTheme.primary`) regardless of mode.
class AppTheme {
  // ---- Brand colors (mode-independent) ----
  // These are the source-of-truth for accent colors. Light/dark variants
  // derive their bg/surface/text from these.
  static const Color primary = Color(0xFF1FAE0D);   // printable green (dark mode)
  static const Color primaryLight = Color(0xFF39FF14); // neon green (used in dark mode)
  static const Color accent = Color(0xFF00A0B0);    // teal/cyan
  static const Color accentLight = Color(0xFF00E5FF); // neon cyan (dark mode)
  static const Color magenta = Color(0xFFFF2BD6);
  static const Color warning = Color(0xFFFFB020);
  static const Color danger = Color(0xFFFF3B3B);

  // ---- Dark mode tokens ----
  static const Color _darkBg = Color(0xFF0A0E14);
  static const Color _darkSurface = Color(0xFF121821);
  static const Color _darkSurfaceAlt = Color(0xFF1A2230);
  static const Color _darkTextPrimary = Color(0xFFF5F7FA);
  static const Color _darkTextSecondary = Color(0xFF9BA8C0);
  static const Color _darkBorder = Color(0xFF243044);

  // ---- Light mode tokens ----
  static const Color _lightBg = Color(0xFFF5F7FA);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightSurfaceAlt = Color(0xFFEFF3F8);
  static const Color _lightTextPrimary = Color(0xFF0A0E14);
  static const Color _lightTextSecondary = Color(0xFF5A6877);
  static const Color _lightBorder = Color(0xFFD8DFE8);

  // ---- Public accessors (always reflect the CURRENT mode) ----
  // These are populated by [_resolve] at theme build time.
  // Widgets read `AppTheme.bg` etc. and get the correct color for the
  // active mode automatically.

  // Dark mode getters (used directly when in dark mode; also used as
  // fallback for cases that hardcode dark neon aesthetic like PDFs).
  static Color get bg => _current._bg;
  static Color get surface => _current._surface;
  static Color get surfaceAlt => _current._surfaceAlt;
  static Color get textPrimary => _current._textPrimary;
  static Color get textSecondary => _current._textSecondary;
  static Color get border => _current._border;

  // Resolve the current mode's tokens into a static holder so getters
  // above don't need to be passed a BuildContext.
  static _ThemeTokens _current = _ThemeTokens(
    _bg: _darkBg,
    _surface: _darkSurface,
    _surfaceAlt: _darkSurfaceAlt,
    _textPrimary: _darkTextPrimary,
    _textSecondary: _darkTextSecondary,
    _border: _darkBorder,
  );

  static void _resolve(Brightness brightness) {
    _current = brightness == Brightness.light
        ? _ThemeTokens(
            _bg: _lightBg,
            _surface: _lightSurface,
            _surfaceAlt: _lightSurfaceAlt,
            _textPrimary: _lightTextPrimary,
            _textSecondary: _lightTextSecondary,
            _border: _lightBorder,
          )
        : _ThemeTokens(
            _bg: _darkBg,
            _surface: _darkSurface,
            _surfaceAlt: _darkSurfaceAlt,
            _textPrimary: _darkTextPrimary,
            _textSecondary: _darkTextSecondary,
            _border: _darkBorder,
          );
  }

  /// Build a ThemeData for the requested brightness.
  /// Light mode uses softer accent colors for accessibility; dark mode
  /// keeps the neon aesthetic.
  static ThemeData forBrightness(Brightness brightness) {
    _resolve(brightness);

    final isLight = brightness == Brightness.light;

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
    );

    // In light mode, use the printable greens/cyans (better contrast).
    // In dark mode, use the neon variants.
    final primaryColor = isLight ? primary : primaryLight;
    final accentColor = isLight ? accent : accentLight;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: brightness,
      primary: primaryColor,
      secondary: accentColor,
      surface: _current._surface,
      error: danger,
      onSurface: _current._textPrimary,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _current._bg,
      canvasColor: _current._bg,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          color: _current._textPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.inter(
          color: _current._textPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: GoogleFonts.inter(
          color: _current._textPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.inter(color: _current._textPrimary),
        bodyMedium: GoogleFonts.inter(color: _current._textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _current._bg,
        foregroundColor: _current._textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: _current._textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: _current._surface,
        elevation: isLight ? 1 : 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _current._border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _current._surfaceAlt,
        hintStyle: TextStyle(color: _current._textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _current._border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _current._border),
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
        backgroundColor: _current._surfaceAlt,
        labelStyle: TextStyle(color: _current._textPrimary),
        side: BorderSide(color: _current._border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dividerColor: _current._border,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _current._surface,
        indicatorColor: primaryColor.withOpacity(0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? primaryColor : _current._textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? primaryColor : _current._textSecondary,
            size: 22,
          );
        }),
      ),
    );
  }

  /// Convenience: dark theme (the original brand aesthetic).
  static ThemeData get dark => forBrightness(Brightness.dark);

  /// Convenience: light theme.
  static ThemeData get light => forBrightness(Brightness.light);
}

/// Internal holder for the current mode's resolved color tokens.
class _ThemeTokens {
  final Color _bg;
  final Color _surface;
  final Color _surfaceAlt;
  final Color _textPrimary;
  final Color _textSecondary;
  final Color _border;

  const _ThemeTokens({
    required Color _bg,
    required Color _surface,
    required Color _surfaceAlt,
    required Color _textPrimary,
    required Color _textSecondary,
    required Color _border,
  })  : _bg = _bg,
        _surface = _surface,
        _surfaceAlt = _surfaceAlt,
        _textPrimary = _textPrimary,
        _textSecondary = _textSecondary,
        _border = _border;
}
