# Release Notes — LoanTracker v3.3.1+36

## What's New

### 📚 Dedicated Loan History tab
A permanent home for every loan you've ever tracked — paid off, in progress, or hidden.

- New **History** tab in the bottom navigation bar (between Payments and Settings)
- Three sections that organise your loans by status:
  - **ACTIVE** — visible loans with a remaining balance or future due date
  - **COMPLETED** — paid-off loans, fully reviewable (no longer auto-hidden!)
  - **HIDDEN** — manually archived loans you can restore any time
- Each loan expands inline to reveal its full payment history (date, M-Pesa code, sender, amount, share-receipt button)
- Per-loan actions: **Make active**, **Hide/Unhide**, **PDF report**, **Delete**
- Search bar to find loans by name, lender, or notes
- Stats strip showing total / active / completed / hidden counts

### 📄 Combined PDF report for all completed loans
A single button on the History screen generates one PDF that covers every completed loan.

- Cover page shows the lifetime totals: number of loans repaid, total repaid amount, total borrowed, total payments logged
- Per-loan index lists every loan with its due date and amount repaid
- One full page section per completed loan, each with:
  - ✓ COMPLETED badge + close date
  - Loan summary (principal, interest, start/due dates, lender)
  - Total Payable / Total Paid / Balance (Ksh 0.00) / Payments count
  - Full transaction table with M-Pesa codes, senders, dates, amounts
- Triggers the system share sheet so you can save, email, or print

### 🏠 Discoverable from the Home screen
- New "Loan history" CTA card at the bottom of the home dashboard shows the active/completed/hidden counts and jumps to the History tab when tapped
- Especially useful for finding paid-off loans that previously "disappeared"

## Bug Fixes

- **Paid loans no longer auto-hide.** Previous versions forced `is_hidden = true` on any loan that was past due AND fully paid, making them vanish from the dashboard and loan switcher with no way back. Completed loans now stay visible by default — the "hide" action is reserved for manual user control.
- **Loan selection prefers an active (not-yet-completed) loan on app launch.** Previously, the auto-active logic could pick a completed loan if it had the nearest due date — now it skips completed loans when there's an active one available.
- **Cached loan totals** (`_loanTotals` map in LoanProvider) — the history screen no longer triggers an N+1 query every time it rebuilds. Totals are refreshed when payments are added/deleted.
- **Fixed missing `lib/repositories/loan_repository.dart`** in the previous deploy zip (would have caused a compile failure on first push — now correctly bundled).

## Architecture & Audit

- **LoanProvider** rewritten:
  - Removed `setLoanHidden(true)` call from `loadLoans()` (the auto-hide bug source)
  - Added `activeLoans`, `completedLoans`, `hiddenLoans` getters
  - Added `isLoanCompleted(loan)` derived-state predicate
  - Added `getPaymentsForLoan(id)` and `getTotalPaidForLoan(id)` so the history screen can fetch data for any loan without making it active first
  - `_loanTotals` cache kept in sync on every add/delete/hide/unhide operation
- **PdfReportService** extended with `generateCompletedLoansPdfAndShare()` — produces a single multi-page PDF covering every completed loan
- **No regressions** of any past broken pattern:
  - ✓ No `withOpacity`, `google_fonts`, `Icons.sms_search`, `cardElevation`, `CardTheme(`, `tooltipBgColor`, `workmanager`, `apply from:`, `minifyEnabled`
  - ✓ `lib/repositories/loan_repository.dart` correctly bundled
  - ✓ All braces/parens/brackets balanced in every modified file
  - ✓ Workflow still pinned to Flutter 3.47.4 with legacy-gradle cleanup step

## Toolchain (unchanged)

- Flutter 3.47.4 (pinned)
- Dart 3.13.3
- Java 17, Gradle 8.14.0, AGP 8.11.1, Kotlin 2.2.20
- Persistent signing keystore — install over v3.3.0+35 without uninstalling

## Files Changed

- `lib/providers/loan_provider.dart` — rewritten (added 4 getters, `isLoanCompleted`, `getPaymentsForLoan`, `getTotalPaidForLoan`, cached totals map, removed auto-hide logic)
- `lib/screens/loan_history_screen.dart` — new file (~1300 lines)
- `lib/screens/home_screen.dart` — added History nav tab, Loan History CTA card, updated Settings shortcut index
- `lib/services/pdf_report_service.dart` — added `generateCompletedLoansPdfAndShare()` + `_buildCompletedLoansDocument()`
- `lib/screens/settings_screen.dart` — updated version labels to v3.3.1+36
- `pubspec.yaml` — version bump to 3.3.1+36

## How to install

1. Download the APK from the GitHub Actions artifacts (or the GitHub Release once the workflow publishes it)
2. Allow "Install from unknown sources" if prompted
3. Tap to install — the persistent keystore allows in-place upgrades over v3.3.0+35 or earlier without uninstalling
4. Your existing loans and payment history are preserved (SQLite database is unchanged at v6)
