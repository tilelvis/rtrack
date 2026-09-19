/// LoanTracker spacing, radii, and duration tokens.
///
/// Use these instead of arbitrary numbers like `13.0` or `27.0`.
/// Values follow an 8-pixel base grid.
///
/// Example:
/// ```dart
/// padding: const EdgeInsets.all(AppSpacing.lg),  // 16.0
/// ```

class AppSpacing {
  AppSpacing._();

  /// 4.0 — tiny gaps (between icon and label inside a button)
  static const double xs = 4.0;

  /// 8.0 — small gaps (between avatar and text)
  static const double sm = 8.0;

  /// 12.0 — medium-small gaps
  static const double mdSm = 12.0;

  /// 16.0 — standard gap between cards / default padding
  static const double md = 16.0;

  /// 20.0 — slightly larger gap
  static const double lg = 20.0;

  /// 24.0 — large gap between sections
  static const double xl = 24.0;

  /// 32.0 — extra large gap (top of screen / hero spacing)
  static const double xxl = 32.0;

  /// Standard screen horizontal padding
  static const double screenH = 16.0;

  /// Standard screen vertical padding (top of scrollable content)
  static const double screenV = 12.0;
}

/// Corner radii used across the app.
class AppRadii {
  AppRadii._();

  /// 8.0 — small chips, badges
  static const double sm = 8.0;

  /// 12.0 — inputs, list tiles, small buttons
  static const double md = 12.0;

  /// 14.0 — primary buttons
  static const double button = 14.0;

  /// 16.0 — medium cards
  static const double lg = 16.0;

  /// 20.0 — primary cards (loan summary, payment action)
  static const double xl = 20.0;

  /// 24.0 — bottom sheets, dialogs, large hero cards
  static const double xxl = 24.0;

  /// 28.0 — pill-shaped chips (fully rounded)
  static const double pill = 28.0;
}

/// Animation durations. Keep these SHORT — financial info should never
/// be hidden behind slow animations.
class AppDurations {
  AppDurations._();

  /// 150ms — quick state changes (taps, toggles)
  static const Duration fast = Duration(milliseconds: 150);

  /// 250ms — standard transitions (theme switch, color changes)
  static const Duration medium = Duration(milliseconds: 250);

  /// 400ms — progress bars, animated containers
  static const Duration slow = Duration(milliseconds: 400);

  /// 600ms — chart entrance, hero animations
  static const Duration hero = Duration(milliseconds: 600);
}
