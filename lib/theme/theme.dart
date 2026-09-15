import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dark neon design system.
class AppTheme {
  static const Color _bg = Color(0xFF0A0E14);
  static const Color _surface = Color(0xFF121821);
  static const Color _surfaceAlt = Color(0xFF1A2230);
  static const Color _primary = Color(0xFF39FF14); // neon green
  static const Color _primaryDim = Color(0xFF1FAE0D);
  static const Color _accent = Color(0xFF00E5FF); // neon cyan
  static const Color _magenta = Color(0xFFFF2BD6);
  static const Color _warning = Color(0xFFFFB020);
  static const Color _danger = Color(0xFFFF3B3B);
  static const Color _textPrimary = Color(0xFFF5F7FA);
  static const Color _textSecondary = Color(0xFF9BA8C0);
  static const Color _border = Color(0xFF243044);

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: Brightness.dark,
      primary: _primary,
      secondary: _accent,
      surface: _surface,
      error: _danger,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _bg,
      canvasColor: _bg,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          color: _textPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.inter(
          color: _textPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: GoogleFonts.inter(
          color: _textPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.inter(color: _textPrimary),
        bodyMedium: GoogleFonts.inter(color: _textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _bg,
        foregroundColor: _textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: _textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: _surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceAlt,
        hintStyle: TextStyle(color: _textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: const Color(0xFF001100),
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
          foregroundColor: _accent,
          side: const BorderSide(color: _accent),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primary,
        foregroundColor: const Color(0xFF001100),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _surfaceAlt,
        labelStyle: const TextStyle(color: _textPrimary),
        side: const BorderSide(color: _border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dividerColor: _border,
    );
  }

  static const Color bg = _bg;
  static const Color surface = _surface;
  static const Color surfaceAlt = _surfaceAlt;
  static const Color primary = _primary;
  static const Color primaryDim = _primaryDim;
  static const Color accent = _accent;
  static const Color magenta = _magenta;
  static const Color warning = _warning;
  static const Color danger = _danger;
  static const Color textPrimary = _textPrimary;
  static const Color textSecondary = _textSecondary;
  static const Color border = _border;
}
