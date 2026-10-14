import 'package:flutter/material.dart';

/// Apple-inspired design system for LoanTracker.
///
/// Design philosophy:
///   - Clean, large-typography surfaces with subtle blur/elevation
///   - SF Pro-style font (Inter is the closest Google Font equivalent)
///   - Soft, rounded corners (20-28px on cards, 14px on buttons)
///   - Restrained color palette — system blue primary, green success,
///     amber warning, red danger. No neon, no gradients, no cyberpunk.
///   - Dark mode: deep charcoal (not pure black), warm-tinted surfaces
///   - Light mode: warm off-white, card elevation via subtle shadows
///
/// Architecture:
///   1. Two complete ColorSchemes (light + dark) — the source of truth
///   2. ThemeExtension<LoanTrackerDesignTokens> for semantic colors
///   3. Widgets obtain colors via Theme.of(context).colorScheme.X
///      or Theme.of(context).extension<LoanTrackerDesignTokens>()!.X
class AppTheme {
  AppTheme._();

  // ---- Apple-style brand colors ----
  static const Color _primaryLight = Color(0xFF007AFF);  // Apple systemBlue
  static const Color _primaryDark = Color(0xFF0A84FF);

  static const Color _secondaryLight = Color(0xFFFF2D55);  // Apple systemPink
  static const Color _secondaryDark = Color(0xFFFF375F);

  static const Color _tertiaryLight = Color(0xFF34C759);  // Apple systemGreen
  static const Color _tertiaryDark = Color(0xFF30D158);

  static const Color _errorLight = Color(0xFFFF3B30);  // Apple systemRed
  static const Color _errorDark = Color(0xFFFF453A);

  // ---- Dark mode: warm charcoal (not pure black) ----
  static const Color _darkBg = Color(0xFF000000);        // Apple true black
  static const Color _darkSurface = Color(0xFF1C1C1E);  // Apple systemBackground secondary
  static const Color _darkSurfaceContainer = Color(0xFF2C2C2E); // tertiary
  static const Color _darkSurfaceHigh = Color(0xFF3A3A3C); // elevated
  static const Color _darkBorder = Color(0xFF38383A);
  static const Color _darkTextPrimary = Color(0xFFFFFFFF);
  static const Color _darkTextSecondary = Color(0xFF8E8E93); // Apple secondaryLabel

  // ---- Light mode: warm off-white ----
  static const Color _lightBg = Color(0xFFF2F2F7);   // Apple systemGroupedBackground
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightSurfaceContainer = Color(0xFFF2F2F7);
  static const Color _lightSurfaceHigh = Color(0xFFE5E5EA);
  static const Color _lightBorder = Color(0xFFC6C6C8);
  static const Color _lightTextPrimary = Color(0xFF000000);
  static const Color _lightTextSecondary = Color(0xFF3C3C43); // Apple secondaryLabel (50% opacity feel)

  // ---- LoanTracker-specific semantic tokens ----
  static const Color _warningLight = Color(0xFFFF9500);  // Apple systemOrange
  static const Color _warningDark = Color(0xFFFF9F0A);

  static const Color _chartPaidLight = Color(0xFF34C759);
  static const Color _chartPaidDark = Color(0xFF30D158);
  static const Color _chartTargetLight = Color(0xFF007AFF);
  static const Color _chartTargetDark = Color(0xFF0A84FF);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: isLight ? _primaryLight : _primaryDark,
      onPrimary: Colors.white,
      primaryContainer: isLight
          ? const Color(0xFFE3F0FF)
          : const Color(0xFF003B66),
      onPrimaryContainer: isLight
          ? const Color(0xFF002B4D)
          : const Color(0xFFB3DAFF),
      secondary: isLight ? _secondaryLight : _secondaryDark,
      onSecondary: Colors.white,
      secondaryContainer: isLight
          ? const Color(0xFFFFE0EC)
          : const Color(0xFF661A33),
      onSecondaryContainer: isLight
          ? const Color(0xFF330011)
          : const Color(0xFFFFD6E0),
      tertiary: isLight ? _tertiaryLight : _tertiaryDark,
      onTertiary: Colors.white,
      tertiaryContainer: isLight
          ? const Color(0xFFD6F5DC)
          : const Color(0xFF1A4D2E),
      onTertiaryContainer: isLight
          ? const Color(0xFF003311)
          : const Color(0xFFB4F0C4),
      error: isLight ? _errorLight : _errorDark,
      onError: Colors.white,
      errorContainer: isLight
          ? const Color(0xFFFFE0E0)
          : const Color(0xFF660000),
      onErrorContainer: isLight
          ? const Color(0xFF330000)
          : const Color(0xFFFFB4B4),
      surface: isLight ? _lightSurface : _darkSurface,
      onSurface: isLight ? _lightTextPrimary : _darkTextPrimary,
      surfaceContainerLowest: isLight ? Colors.white : Colors.black,
      surfaceContainerLow: isLight ? _lightSurface : _darkSurface,
      surfaceContainer: isLight
          ? _lightSurfaceContainer
          : _darkSurfaceContainer,
      surfaceContainerHigh: isLight
          ? _lightSurfaceHigh
          : _darkSurfaceHigh,
      surfaceContainerHighest: isLight
          ? const Color(0xFFD1D1D6)
          : const Color(0xFF48484A),
      onSurfaceVariant: isLight
          ? _lightTextSecondary
          : _darkTextSecondary,
      outline: isLight ? _lightBorder : _darkBorder,
      outlineVariant: isLight
          ? const Color(0xFFE5E5EA)
          : const Color(0xFF2C2C2E),
      shadow: Colors.black,
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
      // Apple apps feel "spread out" — slightly less dense than Material default
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );

    // Use bundled Inter font (closest to SF Pro available on all platforms)
    TextStyle _font(double size, FontWeight weight, Color color,
        {double letterSpacing = 0}) {
      return TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        color: color,
      );
    }

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: _font(36, FontWeight.w800, colorScheme.onSurface, letterSpacing: -0.5),
        displayMedium: _font(28, FontWeight.w700, colorScheme.onSurface, letterSpacing: -0.25),
        displaySmall: _font(24, FontWeight.w700, colorScheme.onSurface),
        headlineMedium: _font(20, FontWeight.w700, colorScheme.onSurface),
        headlineSmall: _font(18, FontWeight.w600, colorScheme.onSurface),
        titleLarge: _font(22, FontWeight.w700, colorScheme.onSurface, letterSpacing: -0.25),
        titleMedium: _font(17, FontWeight.w600, colorScheme.onSurface),
        titleSmall: _font(15, FontWeight.w600, colorScheme.onSurface),
        bodyLarge: _font(17, FontWeight.w400, colorScheme.onSurface),
        bodyMedium: _font(15, FontWeight.w400, colorScheme.onSurfaceVariant),
        bodySmall: _font(13, FontWeight.w400, colorScheme.onSurfaceVariant),
        labelLarge: _font(15, FontWeight.w600, colorScheme.onSurface, letterSpacing: 0.1),
        labelMedium: _font(12, FontWeight.w600, colorScheme.onSurfaceVariant, letterSpacing: 0.1),
        labelSmall: _font(11, FontWeight.w600, colorScheme.onSurfaceVariant, letterSpacing: 0.4),
      ),

      // ---- App Bar — large title style (Apple-like) ----
      appBarTheme: AppBarTheme(
        backgroundColor: isLight ? _lightBg : _darkBg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: _font(34, FontWeight.w800, colorScheme.onSurface, letterSpacing: -0.5),
        toolbarTextStyle: _font(17, FontWeight.w600, colorScheme.onSurface),
      ),

      // ---- Cards — soft, rounded, no visible border (Apple style) ----
      cardTheme: CardThemeData(
        color: isLight ? _lightSurface : _darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // ---- Inputs — rounded, filled ----
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? _lightSurfaceContainer : _darkSurfaceContainer,
        hintStyle: _font(17, FontWeight.w400, colorScheme.onSurfaceVariant),
        labelStyle: _font(15, FontWeight.w500, colorScheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),

      // ---- Buttons — Apple-style rounded rectangles ----
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: _font(17, FontWeight.w600, Colors.white),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: _font(17, FontWeight.w600, Colors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outline, width: 0.5),
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: _font(17, FontWeight.w600, colorScheme.primary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: _font(17, FontWeight.w400, colorScheme.primary),
        ),
      ),

      // ---- FAB — rounded ----
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        extendedTextStyle: _font(15, FontWeight.w600, Colors.white),
      ),

      // ---- Chips — Apple pill style ----
      chipTheme: ChipThemeData(
        backgroundColor: isLight ? _lightSurfaceContainer : _darkSurfaceContainer,
        labelStyle: _font(13, FontWeight.w600, colorScheme.onSurface),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        selectedColor: colorScheme.primaryContainer,
      ),

      // ---- Navigation Bar — Apple tab bar style ----
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isLight
            ? _lightSurface.withValues(alpha: 0.9)
            : _darkSurface.withValues(alpha: 0.9),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        indicatorColor: Colors.transparent, // Apple doesn't use indicator pills
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return _font(10, FontWeight.w600,
              selected ? colorScheme.primary : colorScheme.onSurfaceVariant);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            size: 24,
          );
        }),
      ),

      // ---- ProgressIndicator — Apple blue ----
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.tertiary,
        linearTrackColor: isLight ? _lightSurfaceHigh : _darkSurfaceHigh,
        circularTrackColor: isLight ? _lightSurfaceHigh : _darkSurfaceHigh,
      ),

      // ---- Divider ----
      dividerTheme: DividerThemeData(
        color: isLight ? _lightBorder : _darkBorder,
        thickness: 0.5,
        space: 1,
      ),

      // ---- Snackbar ----
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight ? _lightTextPrimary : _darkTextPrimary,
        contentTextStyle: _font(15, FontWeight.w500,
            isLight ? _lightSurface : _darkSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),

      // ---- Dialog — Apple alert style ----
      dialogTheme: DialogThemeData(
        backgroundColor: isLight ? _lightSurface : _darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: _font(17, FontWeight.w700, colorScheme.onSurface),
        contentTextStyle: _font(13, FontWeight.w400, colorScheme.onSurfaceVariant),
      ),

      // ---- BottomSheet — Apple modal sheet style ----
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isLight ? _lightSurface : _darkSurface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: isLight ? _lightSurface : _darkSurface,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // ---- ListTile ----
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.primary,
        textColor: colorScheme.onSurface,
        titleTextStyle: _font(17, FontWeight.w400, colorScheme.onSurface),
        subtitleTextStyle: _font(13, FontWeight.w400, colorScheme.onSurfaceVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),

      // ---- Extension ----
      extensions: [
        isLight ? _lightDesignTokens : _darkDesignTokens,
      ],
    );
  }

  static final LoanTrackerDesignTokens _lightDesignTokens =
      LoanTrackerDesignTokens(
    brightness: Brightness.light,
    success: _tertiaryLight,
    onSuccess: Colors.white,
    successContainer: const Color(0xFFD6F5DC),
    onSuccessContainer: const Color(0xFF003311),
    warning: _warningLight,
    onWarning: Colors.white,
    warningContainer: const Color(0xFFFFE8CC),
    onWarningContainer: const Color(0xFF4D2600),
    danger: _errorLight,
    onDanger: Colors.white,
    dangerContainer: const Color(0xFFFFE0E0),
    onDangerContainer: const Color(0xFF330000),
    brandPrimary: _primaryLight,
    brandAccent: _secondaryLight,
    brandSuccess: _tertiaryLight,
    chartPaid: _chartPaidLight,
    chartTarget: _chartTargetLight,
    chartGrid: const Color(0xFFE5E5EA),
    brandSurface: const Color(0xFFE3F0FF),
    successSurface: const Color(0xFFE8F7ED),
    warningSurface: const Color(0xFFFFF4E0),
    dangerSurface: const Color(0xFFFFEDEA),
    accentSurface: const Color(0xFFFFE6F0),
    neutralSurface: const Color(0xFFF2F2F7),
  );

  static final LoanTrackerDesignTokens _darkDesignTokens =
      LoanTrackerDesignTokens(
    brightness: Brightness.dark,
    success: _tertiaryDark,
    onSuccess: const Color(0xFF003311),
    successContainer: const Color(0xFF1A4D2E),
    onSuccessContainer: const Color(0xFFB4F0C4),
    warning: _warningDark,
    onWarning: const Color(0xFF4D2600),
    warningContainer: const Color(0xFF4D3000),
    onWarningContainer: const Color(0xFFFFE8CC),
    danger: _errorDark,
    onDanger: const Color(0xFF660000),
    dangerContainer: const Color(0xFF4D0000),
    onDangerContainer: const Color(0xFFFFB4B4),
    brandPrimary: _primaryDark,
    brandAccent: _secondaryDark,
    brandSuccess: _tertiaryDark,
    chartPaid: _chartPaidDark,
    chartTarget: _chartTargetDark,
    chartGrid: const Color(0xFF38383A),
    brandSurface: const Color(0xFF003B66),
    successSurface: const Color(0xFF1A4D2E),
    warningSurface: const Color(0xFF4D3000),
    dangerSurface: const Color(0xFF4D0000),
    accentSurface: const Color(0xFF661A33),
    neutralSurface: const Color(0xFF2C2C2E),
  );
}

@immutable
class LoanTrackerDesignTokens
    extends ThemeExtension<LoanTrackerDesignTokens> {
  final Brightness brightness;
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
  final Color brandPrimary;
  final Color brandAccent;
  final Color brandSuccess;
  final Color chartPaid;
  final Color chartTarget;
  final Color chartGrid;
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
