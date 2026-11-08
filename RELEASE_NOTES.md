# Release Notes — LoanTracker v3.3.2+37

> Patch release fixing the 3 analyzer errors that blocked the v3.3.1+36 build.

## Build Fix

The v3.3.1+36 push failed `flutter analyze` with three error-level issues. All three are now fixed:

### 1. `home_screen.dart` — `LoanTrackerDesignTokens isn't a type`
The new `_LoanHistoryCta` widget used `Theme.of(context).extension<LoanTrackerDesignTokens>()!` but `home_screen.dart` didn't import the file that declares `LoanTrackerDesignTokens`. Added the missing import:
```dart
import '../theme/theme.dart';
```

### 2. `loan_history_screen.dart` — `Invalid constant value`
The expandable loan card used `const BorderRadius.only(...)` whose `bottomLeft` / `bottomRight` corners depended on a runtime `_expanded` flag — `const` requires compile-time-constant expressions. Removed the `const` keyword from the `BorderRadius.only(...)` call so it evaluates at runtime.

### 3. `loan_history_screen.dart` — `argument_type_not_assignable (num → double)`
`(total - paid).clamp(0, double.infinity)` returns `num` (not `double`) because `0` is an `int`. Passing it to `_buildExpanded(balance: balance)` — whose parameter is typed `double` — failed. Added `.toDouble()`:
```dart
final balance = (total - paid).clamp(0.0, double.infinity).toDouble();
```
Also applied the same `.toDouble()` to `progress` for consistency.

### Additional cleanup (info-level, didn't block)
- Removed unused `isMpesa` local variable in `_PaymentRow.build`
- Added `if (!mounted) return;` guards and captured theme colors BEFORE `await` in `_generateCompletedPdf` and `_exportPdf`, to clear the `use_build_context_synchronously` lints

## What's still in this release (carried from v3.3.1+36)

- 📚 **Loan History tab** — Active / Completed / Hidden sections, expandable per-loan cards with full payment history
- 📄 **Combined "Download completed loans PDF"** — single PDF covering every completed loan (cover page with lifetime totals + per-loan pages)
- 🏠 **Loan History CTA** on the home dashboard so completed loans are discoverable
- **Paid loans no longer auto-hide** — the bug that made completed loans "disappear" is fixed
- **Cached `_loanTotals` map** to avoid N+1 queries when the history screen rebuilds
- **Fixed missing `lib/repositories/loan_repository.dart`** in the previous deploy zip

## Audit (loop engineering)

Verified the v3.3.2+37 zip against every known broken pattern from build history:

| Pattern | Status |
|---|---|
| `withOpacity` | ✓ absent |
| `google_fonts` / `GoogleFonts` | ✓ absent |
| `Icons.sms_search` | ✓ absent |
| `cardElevation` | ✓ absent |
| `CardTheme(` (without `Data`) | ✓ absent |
| `tooltipBgColor` | ✓ absent |
| `workmanager` | ✓ absent |
| `minifyEnabled` (without `is-` prefix) | ✓ absent |
| `apply from:` | ✓ absent |
| `StreamSubscription` on `listenIncomingSms` (void) | ✓ absent |
| `const BorderRadius.only` with non-const ternary | ✓ absent (this fix) |
| `clamp(0, double.infinity)` passed to `double` param | ✓ absent (this fix) |
| `LoanTrackerDesignTokens` used without `theme.dart` import | ✓ absent (this fix) |

Plus:
- ✓ All braces/parens/brackets balanced in every modified file
- ✓ Workflow still pinned to Flutter 3.47.4 + Java 17 + AGP 8.11.1 + Kotlin 2.2.20
- ✓ Static analysis step uses `--no-fatal-infos --no-fatal-warnings` so infos/warnings don't block
- ✓ Legacy Groovy gradle files removed (`android/build.gradle`, `android/settings.gradle`, `android/app/build.gradle`)
- ✓ `lib/repositories/loan_repository.dart` correctly bundled
- ✓ Persistent signing keystore + `key.properties` present (allows in-place upgrade over v3.3.1+36 without uninstall)

## Files Changed (since v3.3.1+36)

- `lib/screens/home_screen.dart` — added missing `import '../theme/theme.dart';`
- `lib/screens/loan_history_screen.dart`:
  - Removed `const` from `BorderRadius.only(...)` (line ~623)
  - Added `.toDouble()` to `balance` and `progress` (lines ~588, ~590)
  - Removed unused `isMpesa` variable in `_PaymentRow`
  - Added `if (!mounted) return;` guards in `_generateCompletedPdf` and `_exportPdf`
  - Captured theme colors BEFORE `await` to clear `use_build_context_synchronously` lint
- `lib/screens/settings_screen.dart` — updated version labels to `v3.3.2+37`
- `pubspec.yaml` — version bump to `3.3.2+37`

## Toolchain (unchanged)

- Flutter 3.47.4 (pinned)
- Dart 3.13.3
- Java 17, Gradle 8.14.0, AGP 8.11.1, Kotlin 2.2.20
- Persistent signing keystore — install over v3.3.1+36 without uninstalling

## Install

Same persistent keystore as v3.3.1+36 — install over the top without uninstalling. Your loan and payment data is preserved (SQLite schema unchanged at v6).
