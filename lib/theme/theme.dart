import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Material 3 design system for LoanTracker.
///
/// Inspired by the reference screens (premium fintech, midnight navy
/// dark mode, off-white light mode) but translated into proper
/// Material 3 — no neon glow, no cyberpunk, no scattered hardcoded colors.
///
/// ARCHITECTURE
/// ============
/// 1. Two complete ColorSchemes (light + dark) — the source of truth.
/// 2. A ThemeExtension<LoanTrackerDesignTokens> for LoanTracker-specific
///    semantic colors not covered by ColorScheme (success, warning,
///    pending, chart colors, brand accents).
/// 3. Widgets obtain colors via:
///       Theme.of(context).colorScheme.X           (standard M3)
///       Theme.of(context).extension<LoanTrackerDesignTokens>()!.X  (custom)
///    NEVER via AppTheme.X directly.
///
/// COLOR PHILOSOPHY
/// ================
/// - Primary: cyan/blue (interaction, navigation selection, links)
/// - Secondary: magenta (ACCENT ONLY — never the dominant color)
/// - Tertiary: green (positive financial progress, successful payments)
/// - Error: red (overdue, destructive)
/// - Surface: navy (dark) / off-white (light)
///
/// Dark mode is "premium midnight fintech" — deep navy, not pure black.
/// Light mode is "premium banking app" — off-white, soft elevation.
class AppTheme {
  AppTheme._();

  // ===========================================================================
  // SEMANTIC BRAND COLORS — used by both ColorScheme and DesignTokens
  // ===========================================================================

  // Primary: cyan/blue — interaction color
  static const Color _primaryLight = Color(0xFF0064A8);   // strong blue on light bg
  static const Color _primaryDark = Color(0xFF62B5E8);    // soft cyan on dark bg

  // Secondary: magenta/pink — accent only
  static const Color _secondaryLight = Color(0xFF9C2D5C);
  static const Color _secondaryDark = Color(0xFFFFB0D0);

  // Tertiary: green — positive financial progress
  static const Color _tertiaryLight = Color(0xFF1F7A3D);
  static const Color _tertiaryDark = Color(0xFF7DD9A1);

  // Error: red — destructive / overdue
  static const Color _errorLight = Color(0xFFBA1A1A);
  static const Color _errorDark = Color(0xFFFFB4AB);

  // ===========================================================================
  // DARK MODE — "premium midnight fintech"
  // Deep navy background (NOT pure black), elevated navy surfaces.
  // ===========================================================================
  static const Color _darkBg = Color(0xFF0B1120);          // deep midnight navy
  static const Color _darkSurface = Color(0xFF131C2E);    // elevated navy
  static const Color _darkSurfaceContainer = Color(0xFF1A2540); // grouped content
  static const Color _darkSurfaceHigh = Color(0xFF223052);    // highest elevation
  static const Color _darkBorder = Color(0xFF2A3858);      // subtle navy border
  static const Color _darkTextPrimary = Color(0xFFEAF0FB);  // near-white
  static const Color _darkTextSecondary = Color(0xFF9BA8C6); // muted blue-gray

  // ===========================================================================
  // LIGHT MODE — "premium banking app"
  // Off-white background, white surfaces, subtle cool-gray borders.
  // ===========================================================================
  static const Color _lightBg = Color(0xFFF4F6FB);        // very light cool gray
  static const Color _lightSurface = Color(0xFFFFFFFF);   // pure white
  static const Color _lightSurfaceContainer = Color(0xFFEFF2F8);
  static const Color _lightSurfaceHigh = Color(0xFFE6EAF2);
  static const Color _lightBorder = Color(0xFFD8DEE8);    // subtle cool gray
  static const Color _lightTextPrimary = Color(0xFF0F1B2D);  // deep navy
  static const Color _lightTextSecondary = Color(0xFF5A6B85); // slate

  // ===========================================================================
  // LOANTRACKER-SPECIFIC SEMANTIC TOKENS
  // These are NOT in ColorScheme, so they live in ThemeExtension.
  // ===========================================================================

  // Warning: amber — pending / due soon / attention
  static const Color _warningLight = Color(0xFFB45300);
  static const Color _warningDark = Color(0xFFFFB877);

  // Chart palette
  static const Color _chartPaidLight = Color(0xFF1F7A3D);   // emerald
  static const Color _chartPaidDark = Color(0xFF7DD9A1);
  static const Color _chartTargetLight = Color(0xFF0064A8);  // dashed target line
  static const Color _chartTargetDark = Color(0xFF62B5E8);

  // ===========================================================================
  // LIGHT ColorScheme
  // ===========================================================================
  static ThemeData get light => _build(Brightness.light);

  // ===========================================================================
  // DARK ColorScheme
  // ===========================================================================
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: isLight ? _primaryLight : _primaryDark,
      onPrimary: isLight ? Colors.white : const Color(0xFF002A47),
      primaryContainer: isLight
          ? const Color(0xFFD5E3FF)
          : const Color(0xFF004A75),
      onPrimaryContainer: isLight
          ? const Color(0xFF001D36)
          : const Color(0xFFC7E5FF),
      secondary: isLight ? _secondaryLight : _secondaryDark,
      onSecondary: isLight ? Colors.white : const Color(0xFF56162E),
      secondaryContainer: isLight
          ? const Color(0xFFFFD8E5)
          : const Color(0xFF7A2D52),
      onSecondaryContainer: isLight
          ? const Color(0xFF3E0720)
          : const Color(0xFFFFD8E5),
      tertiary: isLight ? _tertiaryLight : _tertiaryDark,
      onTertiary: isLight ? Colors.white : const Color(0xFF00391C),
      tertiaryContainer: isLight
          ? const Color(0xFFB4EFC2)
          : const Color(0xFF1E5232),
      onTertiaryContainer: isLight
          ? const Color(0xFF00210F)
          : const Color(0xFFB4EFC2),
      error: isLight ? _errorLight : _errorDark,
      onError: isLight ? Colors.white : const Color(0xFF690005),
      errorContainer: isLight
          ? const Color(0xFFFFDAD6)
          : const Color(0xFF93000A),
      onErrorContainer: isLight
          ? const Color(0xFF410002)
          : const Color(0xFFFFDAD6),
      surface: isLight ? _lightSurface : _darkSurface,
      onSurface: isLight ? _lightTextPrimary : _darkTextPrimary,
      surfaceContainerLowest: isLight ? Colors.white : const Color(0xFF060B14),
      surfaceContainerLow: isLight ? _lightSurface : _darkSurface,
      surfaceContainer: isLight
          ? _lightSurfaceContainer
          : _darkSurfaceContainer,
      surfaceContainerHigh: isLight
          ? _lightSurfaceHigh
          : _darkSurfaceHigh,
      surfaceContainerHighest: isLight
          ? const Color(0xFFDDE3EE)
          : const Color(0xFF2C3A5E),
      onSurfaceVariant: isLight
          ? _lightTextSecondary
          : _darkTextSecondary,
      outline: isLight ? _lightBorder : _darkBorder,
      outlineVariant: isLight
          ? const Color(0xFFC2C8D2)
          : const Color(0xFF444B66),
      shadow: isLight ? const Color(0xFF000000) : Colors.black,
      scrim: Colors.black,
      inverseSurface: isLight ? _darkSurface : _lightSurface,
      onInverseSurface: isLight ? _darkTextPrimary : _lightTextPrimary,
      inversePrimary: isLight ? _primaryDark : _primaryLight,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isLight ? _lightBg : _darkBg,
      canvasColor: isLight ? _lightBg : _darkBg,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      // ---- Typography ----
      // JetBrains Mono for headings, labels, and figures (gives LoanTracker
      // a distinctive technical/fintech identity with tabular figures that
      // align nicely in financial displays).
      // Inter remains for body text (better paragraph readability).
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.jetBrainsMono(
          fontSize: 36,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: colorScheme.onSurface,
        ),
        displayMedium: GoogleFonts.jetBrainsMono(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
          color: colorScheme.onSurface,
        ),
        displaySmall: GoogleFonts.jetBrainsMono(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: colorScheme.onSurface,
        ),
        headlineMedium: GoogleFonts.jetBrainsMono(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: colorScheme.onSurface,
        ),
        headlineSmall: GoogleFonts.jetBrainsMono(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
        titleLarge: GoogleFonts.jetBrainsMono(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
        titleMedium: GoogleFonts.jetBrainsMono(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        titleSmall: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        bodyLarge: GoogleFonts.jetBrainsMono(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurface,
        ),
        bodyMedium: GoogleFonts.jetBrainsMono(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurfaceVariant,
        ),
        bodySmall: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurfaceVariant,
        ),
        labelLarge: GoogleFonts.jetBrainsMono(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: colorScheme.onSurface,
        ),
        labelMedium: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: colorScheme.onSurfaceVariant,
        ),
        labelSmall: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      // ---- App Bar — flat, no elevation, surface-tinted ----
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: GoogleFonts.jetBrainsMono(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
      ),

      // ---- Cards — Material 3 outlined / filled variants ----
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),

      // ---- Inputs ----
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHigh,
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
      ),

      // ---- Buttons — Material 3 hierarchy ----
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.jetBrainsMono(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.jetBrainsMono(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outline),
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.jetBrainsMono(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: GoogleFonts.jetBrainsMono(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),

      // ---- FAB ----
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        extendedTextStyle: GoogleFonts.jetBrainsMono(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),

      // ---- Chips — Material 3 tonal ----
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        labelStyle: TextStyle(color: colorScheme.onSurface),
        side: BorderSide(color: colorScheme.outline, width: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        selectedColor: colorScheme.primaryContainer,
      ),

      // ---- Navigation Bar — Material 3 ----
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        elevation: 0,
        height: 72,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
            size: 22,
          );
        }),
      ),

      // ---- ProgressIndicator — uses tertiary (green) for repayment progress ----
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.tertiary,
        linearTrackColor: colorScheme.surfaceContainerHigh,
        circularTrackColor: colorScheme.surfaceContainerHigh,
      ),

      // ---- Divider ----
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 0.5,
        space: 1,
      ),

      // ---- Snackbar ----
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // ---- Dialog ----
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: GoogleFonts.jetBrainsMono(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
        contentTextStyle: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      // ---- BottomSheet ----
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        modalBackgroundColor: colorScheme.surface,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // ---- ListTile ----
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.primary,
        textColor: colorScheme.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // ---- Extension ----
      extensions: [
        isLight ? _lightDesignTokens : _darkDesignTokens,
      ],
    );
  }

  // ===========================================================================
  // LOANTRACKER DESIGN TOKENS — ThemeExtension
  // ===========================================================================
  static final LoanTrackerDesignTokens _lightDesignTokens =
      LoanTrackerDesignTokens(
    brightness: Brightness.light,
    // Semantic statuses
    success: _tertiaryLight,
    onSuccess: Colors.white,
    successContainer: const Color(0xFFB4EFC2),
    onSuccessContainer: const Color(0xFF00210F),
    warning: _warningLight,
    onWarning: Colors.white,
    warningContainer: const Color(0xFFFFE0B0),
    onWarningContainer: const Color(0xFF3D1F00),
    danger: _errorLight,
    onDanger: Colors.white,
    dangerContainer: const Color(0xFFFFDAD6),
    onDangerContainer: const Color(0xFF410002),
    // Brand accents
    brandPrimary: _primaryLight,
    brandAccent: _secondaryLight,
    brandSuccess: _tertiaryLight,
    // Charts
    chartPaid: _chartPaidLight,
    chartTarget: _chartTargetLight,
    chartGrid: const Color(0xFFE0E5EE),
    // Surfaces (extra levels beyond ColorScheme)
    brandSurface: const Color(0xFFF0F7FF),     // very pale blue (hero card)
    successSurface: const Color(0xFFE8F7ED),  // pale green
    warningSurface: const Color(0xFFFFF4E0),  // pale amber
    dangerSurface: const Color(0xFFFFEDEA),   // pale red
    accentSurface: const Color(0xFFFFE6F0),   // pale pink
    neutralSurface: const Color(0xFFEFF2F8),  // pale gray
  );

  static final LoanTrackerDesignTokens _darkDesignTokens =
      LoanTrackerDesignTokens(
    brightness: Brightness.dark,
    // Semantic statuses
    success: _tertiaryDark,
    onSuccess: const Color(0xFF00391C),
    successContainer: const Color(0xFF1E5232),
    onSuccessContainer: const Color(0xFFB4EFC2),
    warning: _warningDark,
    onWarning: const Color(0xFF4A2800),
    warningContainer: const Color(0xFF5A3D0E),
    onWarningContainer: const Color(0xFFFFE0B0),
    danger: _errorDark,
    onDanger: const Color(0xFF690005),
    dangerContainer: const Color(0xFF93000A),
    onDangerContainer: const Color(0xFFFFDAD6),
    // Brand accents
    brandPrimary: _primaryDark,
    brandAccent: _secondaryDark,
    brandSuccess: _tertiaryDark,
    // Charts
    chartPaid: _chartPaidDark,
    chartTarget: _chartTargetDark,
    chartGrid: const Color(0xFF2A3858),
    // Surfaces (extra levels beyond ColorScheme)
    brandSurface: const Color(0xFF0F1F36),     // tinted hero card
    successSurface: const Color(0xFF122D20),   // pale green tint
    warningSurface: const Color(0xFF2E2310),   // pale amber tint
    dangerSurface: const Color(0xFF2B1014),    // pale red tint
    accentSurface: const Color(0xFF2A1424),     // pale pink tint
    neutralSurface: const Color(0xFF1A2540),   // navy variant
  );
}

/// LoanTracker-specific design tokens, exposed via ThemeExtension.
///
/// Use:
/// ```dart
/// final tokens = Theme.of(context).extension<LoanTrackerDesignTokens>()!;
/// Container(color: tokens.success);
/// ```
///
/// These tokens cover semantic states (success / warning / danger) and
/// brand accents that don't fit into Material's ColorScheme.
@immutable
class LoanTrackerDesignTokens
    extends ThemeExtension<LoanTrackerDesignTokens> {
  final Brightness brightness;

  // ---- Semantic statuses ----
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color danger;
  final Color onDanger;
  final Color dangerContainer;
  final Color onDangerContainer;

  // ---- Brand accents ----
  final Color brandPrimary;   // cyan/blue
  final Color brandAccent;    // magenta (use sparingly!)
  final Color brandSuccess;   // green

  // ---- Charts ----
  final Color chartPaid;
  final Color chartTarget;
  final Color chartGrid;

  // ---- Tinted surfaces for emphasis cards ----
  final Color brandSurface;
  final Color successSurface;
  final Color warningSurface;
  final Color dangerSurface;
  final Color accentSurface;
  final Color neutralSurface;

  const LoanTrackerDesignTokens({
    required this.brightness,
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.danger,
    required this.onDanger,
    required this.dangerContainer,
    required this.onDangerContainer,
    required this.brandPrimary,
    required this.brandAccent,
    required this.brandSuccess,
    required this.chartPaid,
    required this.chartTarget,
    required this.chartGrid,
    required this.brandSurface,
    required this.successSurface,
    required this.warningSurface,
    required this.dangerSurface,
    required this.accentSurface,
    required this.neutralSurface,
  });

  @override
  ThemeExtension<LoanTrackerDesignTokens> copyWith({
    Brightness? brightness,
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? danger,
    Color? onDanger,
    Color? dangerContainer,
    Color? onDangerContainer,
    Color? brandPrimary,
    Color? brandAccent,
    Color? brandSuccess,
    Color? chartPaid,
    Color? chartTarget,
    Color? chartGrid,
    Color? brandSurface,
    Color? successSurface,
    Color? warningSurface,
    Color? dangerSurface,
    Color? accentSurface,
    Color? neutralSurface,
  }) {
    return LoanTrackerDesignTokens(
      brightness: brightness ?? this.brightness,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      onDangerContainer: onDangerContainer ?? this.onDangerContainer,
      brandPrimary: brandPrimary ?? this.brandPrimary,
      brandAccent: brandAccent ?? this.brandAccent,
      brandSuccess: brandSuccess ?? this.brandSuccess,
      chartPaid: chartPaid ?? this.chartPaid,
      chartTarget: chartTarget ?? this.chartTarget,
      chartGrid: chartGrid ?? this.chartGrid,
      brandSurface: brandSurface ?? this.brandSurface,
      successSurface: successSurface ?? this.successSurface,
      warningSurface: warningSurface ?? this.warningSurface,
      dangerSurface: dangerSurface ?? this.dangerSurface,
      accentSurface: accentSurface ?? this.accentSurface,
      neutralSurface: neutralSurface ?? this.neutralSurface,
    );
  }

  @override
  ThemeExtension<LoanTrackerDesignTokens> lerp(
    ThemeExtension<LoanTrackerDesignTokens>? other,
    double t,
  ) {
    if (other is! LoanTrackerDesignTokens) return this;
    return LoanTrackerDesignTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer: Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer: Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
      onDangerContainer: Color.lerp(onDangerContainer, other.onDangerContainer, t)!,
      brandPrimary: Color.lerp(brandPrimary, other.brandPrimary, t)!,
      brandAccent: Color.lerp(brandAccent, other.brandAccent, t)!,
      brandSuccess: Color.lerp(brandSuccess, other.brandSuccess, t)!,
      chartPaid: Color.lerp(chartPaid, other.chartPaid, t)!,
      chartTarget: Color.lerp(chartTarget, other.chartTarget, t)!,
      chartGrid: Color.lerp(chartGrid, other.chartGrid, t)!,
      brandSurface: Color.lerp(brandSurface, other.brandSurface, t)!,
      successSurface: Color.lerp(successSurface, other.successSurface, t)!,
      warningSurface: Color.lerp(warningSurface, other.warningSurface, t)!,
      dangerSurface: Color.lerp(dangerSurface, other.dangerSurface, t)!,
      accentSurface: Color.lerp(accentSurface, other.accentSurface, t)!,
      neutralSurface: Color.lerp(neutralSurface, other.neutralSurface, t)!,
    );
  }
}

/// Convenience accessor for the design tokens extension.
LoanTrackerDesignTokens designTokensOf(BuildContext context) {
  return Theme.of(context).extension<LoanTrackerDesignTokens>()!;
}
