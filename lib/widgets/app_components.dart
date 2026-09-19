import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import '../theme/theme.dart';

/// A reusable Material 3 card with consistent radius, padding, and
/// optional tinted surface for emphasis.
///
/// Variants:
///   - [AppCard.outlined] — default, subtle border, no fill tint
///   - [AppCard.filled] — solid surfaceContainer fill
///   - [AppCard.tinted] — tinted background (e.g. success, warning, brand)
///
/// Use [tintColor] from LoanTrackerDesignTokens for tinted variants:
/// ```dart
/// AppCard.tinted(
///   tintColor: tokens.successSurface,
///   child: ...,
/// )
/// ```
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? _backgroundColor;
  final Color? _borderColor;
  final bool _isFilled;
  final bool _isTinted;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
  })  : _backgroundColor = null,
        _borderColor = null,
        _isFilled = false,
        _isTinted = false;

  const AppCard.filled({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
  })  : _backgroundColor = null,
        _borderColor = null,
        _isFilled = true,
        _isTinted = false;

  const AppCard.tinted({
    super.key,
    required this.child,
    required Color tintColor,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
  })  : _backgroundColor = tintColor,
        _borderColor = null,
        _isFilled = false,
        _isTinted = true;

  const AppCard.custom({
    super.key,
    required this.child,
    required Color backgroundColor,
    Color? borderColor,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
  })  : _backgroundColor = backgroundColor,
        _borderColor = borderColor,
        _isFilled = false,
        _isTinted = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final bgColor = _backgroundColor ??
        (_isFilled ? scheme.surfaceContainerHigh : scheme.surface);
    final borderColor = _borderColor ??
        (_isTinted ? Colors.transparent : scheme.outlineVariant);

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.xl),
      side: _isTinted
          ? BorderSide.none
          : BorderSide(color: borderColor, width: 0.5),
    );

    final material = Material(
      color: bgColor,
      surfaceTintColor: _isTinted ? Colors.transparent : scheme.surfaceTint,
      shape: shape,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );

    return material;
  }
}

/// A section header with a small accent bar, title, and optional trailing
/// action (typically a "View all" link).
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTrailingTap;
  final String? trailingLabel;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTrailingTap,
    this.trailingLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(
        bottom: AppSpacing.sm,
        left: AppSpacing.xs,
        right: AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Accent bar
          Container(
            width: 3,
            height: 16,
            margin: const EdgeInsets.only(right: AppSpacing.sm),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (trailingLabel != null)
            TextButton(
              onPressed: onTrailingTap,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
              child: Text(trailingLabel!),
            ),
        ],
      ),
    );
  }
}

/// A compact metric card showing a label, value, and optional icon.
///
/// Used for the "Paid / Total / Days Left" row on the dashboard.
class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? tintColor;
  final Color? iconColor;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.tintColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final tokens = Theme.of(context).extension<LoanTrackerDesignTokens>();

    final Color bg;
    final Color iconBg;
    final Color iconFg;
    if (tintColor != null) {
      bg = tintColor!;
      iconBg = (iconColor ?? scheme.primary).withOpacity(0.15);
      iconFg = iconColor ?? scheme.primary;
    } else {
      bg = scheme.surfaceContainerHigh;
      iconBg = scheme.surfaceContainerHighest;
      iconFg = scheme.onSurfaceVariant;
    }

    return AppCard.tinted(
      tintColor: bg,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.mdSm,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Icon(icon, size: 16, color: iconFg),
            )
          else
            const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: text.labelMedium,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
                fontSize: 17,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Status chip for payment type badges, "TODAY" / "PENDING" indicators.
///
/// Variants:
///   - [StatusChipVariant.success] — green tint
///   - [StatusChipVariant.warning] — amber tint
///   - [StatusChipVariant.danger] — red tint
///   - [StatusChipVariant.neutral] — gray tint
///   - [StatusChipVariant.brand] — primary blue tint
///   - [StatusChipVariant.accent] — magenta tint
enum StatusChipVariant {
  success,
  warning,
  danger,
  neutral,
  brand,
  accent,
}

class StatusChip extends StatelessWidget {
  final String label;
  final StatusChipVariant variant;
  final IconData? icon;

  const StatusChip({
    super.key,
    required this.label,
    this.variant = StatusChipVariant.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LoanTrackerDesignTokens>()!;
    final text = Theme.of(context).textTheme;

    late Color bg, fg;
    switch (variant) {
      case StatusChipVariant.success:
        bg = tokens.successContainer;
        fg = tokens.onSuccessContainer;
        break;
      case StatusChipVariant.warning:
        bg = tokens.warningContainer;
        fg = tokens.onWarningContainer;
        break;
      case StatusChipVariant.danger:
        bg = tokens.dangerContainer;
        fg = tokens.onDangerContainer;
        break;
      case StatusChipVariant.neutral:
        bg = Theme.of(context).colorScheme.surfaceContainerHighest;
        fg = Theme.of(context).colorScheme.onSurfaceVariant;
        break;
      case StatusChipVariant.brand:
        bg = Theme.of(context).colorScheme.primaryContainer;
        fg = Theme.of(context).colorScheme.onPrimaryContainer;
        break;
      case StatusChipVariant.accent:
        bg = Theme.of(context).colorScheme.secondaryContainer;
        fg = Theme.of(context).colorScheme.onSecondaryContainer;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: text.labelSmall?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

/// A small circular icon container used inside cards.
class IconBubble extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  final double iconSize;

  const IconBubble({
    super.key,
    required this.icon,
    this.color,
    this.size = 36,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Icon(icon, size: iconSize, color: c),
    );
  }
}
