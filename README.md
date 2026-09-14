# Loan Tracker

A personal loan repayment tracker for Android, built with **Flutter (Dart)** and **Material 3**. Designed for tracking a single short-term loan (e.g. a 30-day loan payable in weekly or custom-interval installments), recording M-Pesa payment messages, and reminding you daily to make a payment.

## Features

- **Loan setup** — principal, interest rate, start/due dates, weekly or custom-day payment interval, expected amount per interval.
- **Dashboard** — progress ring, balance remaining, days left, "today paid?" status.
- **Home transactions table** — compact table of recent payments (date, M-Pesa code, sender, amount, type badge) directly on the home screen.
- **PDF report export** — generate a printable PDF report with loan summary, totals box, progress bar, and full transaction table (date, M-Pesa code, sender, type, amount). Share via the system share sheet (save to files, send via WhatsApp/email, print).
- **M-Pesa SMS paste** — paste a Safaricom M-Pesa confirmation SMS and auto-extract:
  - Amount (Ksh / KES)
  - M-Pesa transaction code (e.g. `SI7K2PX1HZ`)
  - Date & time
  - Sender / recipient name
  - Phone number
  - Original message is stored verbatim for audit.
- **Payment history** — full log per loan, with M-Pesa code chips and source (mpesa/manual).
- **Local notifications** — daily reminder at a configurable time (default 08:00), with a test button.
- **Offline-first** — all data stored in on-device SQLite (`loan_tracker.db`). No account, no cloud.
- **Dark neon design** — near-black background, neon-green primary, neon-cyan secondary, Material 3.

## Tech Stack

| Layer | Tech |
| --- | --- |
| UI | Flutter 3.19+, Material 3, Google Fonts (Inter) |
| State | Provider |
| Storage | sqflite + path |
| Notifications | flutter_local_notifications + timezone |
| Scheduling | workmanager (background tasks) |
| M-Pesa parsing | custom regex parser (`lib/services/mpesa_parser.dart`) |
| PDF reports | pdf + share_plus |
| Build/CI | GitHub Actions (manual dispatch), Flutter Action |

## Project Layout

```
loan_tracker/
├── .github/workflows/
│   └── build_apk.yml          # Manual-dispatch APK build + version bump
├── android/                   # Native Android shell (Manifest, gradle, MainActivity)
│   ├── app/build.gradle
│   ├── settings.gradle
│   └── src/main/
│       ├── AndroidManifest.xml
│       ├── kotlin/com/example/loan_tracker/MainActivity.kt
│       └── res/{drawable,values,mipmap-*}/
├── assets/icons/              # Launcher icon assets
├── lib/
│   ├── main.dart              # App entry, init notifications + loans
│   ├── theme/theme.dart       # Dark neon Material 3 theme
│   ├── models/
│   │   ├── loan.dart          # Loan + PaymentInterval enum
│   │   └── payment.dart       # Payment + PaymentSource enum
│   ├── services/
│   │   ├── database_service.dart     # SQLite schema + CRUD
│   │   ├── mpesa_parser.dart         # M-Pesa SMS regex parser
│   │   ├── notification_service.dart # Daily reminders
│   │   └── pdf_report_service.dart   # PDF report generation
│   ├── providers/
│   │   └── loan_provider.dart # ChangeNotifier view-model
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── create_loan_screen.dart
│   │   ├── mpesa_paste_screen.dart
│   │   ├── payment_history_screen.dart
│   │   └── settings_screen.dart
│   └── widgets/
│       ├── dashboard_card.dart
│       ├── payment_history_list.dart
│       └── transactions_table.dart
├── pubspec.yaml               # version: 1.1.0+2  (semantic + build)
├── analysis_options.yaml
└── README.md
```

## Versioning

The app uses **both** semantic version and build number, in the form `MAJOR.MINOR.PATCH+BUILD` (e.g. `1.1.0+2`).

- `version` field in `pubspec.yaml` is the single source of truth.
- `versionCode` (Android integer) = build number.
- `versionName` (Android string) = semantic version.

### Auto-versioning (default behaviour)

When you trigger the **Build APK** workflow without filling in the optional `version` or `build_number` inputs, the workflow **auto-bumps** both:

| Field | Default action |
| --- | --- |
| Semantic version | Patch component +1 (e.g. `1.1.0` → `1.1.1`, `2.3.7` → `2.3.8`) |
| Build number | +1 (e.g. `2` → `3`) |

So each manual dispatch produces a strictly higher version than the previous run. The previous values are read from the **first** `version: X.Y.Z+N` line in `pubspec.yaml` (robust against duplicate lines).

### Manual override

If you want to jump to a specific version (e.g. `2.0.0` for a breaking change, or `1.2.0` for a minor feature), fill in the `version` input. You can override just the version, just the build number, or both.

### Workflow steps

1. Reads the current `version: X.Y.Z+N` from `pubspec.yaml` (first matching line only, validated against a strict regex).
2. Computes new version: input value if provided, else patch+1.
3. Computes new build: input value if provided, else current+1.
4. Validates both (regex `^[0-9]+\.[0-9]+\.[0-9]+$` for version, `^[0-9]+$` for build).
5. Updates the **first** `version:` line in `pubspec.yaml` (leaves any stray duplicates alone but warns).
6. Builds the APK with `--build-name` and `--build-number` flags.
7. Commits the bumped `pubspec.yaml` back to the repo with a `chore(release): vX.Y.Z+N` message.

## Building the APK

### Option A — GitHub Actions (recommended)

1. Push this project to a GitHub repository.
2. Go to **Actions** → **Build APK** workflow.
3. Click **Run workflow**.
4. Choose:
   - `version` (optional, e.g. `1.2.0`)
   - `build_number` (optional, e.g. `5`)
   - `build_type` (debug or release)
5. After the run completes, download the artifact from the workflow run page:
   ```
   loan_tracker-<version>+<build>-<type>.zip
     ├── loan_tracker-<version>+<build>-<type>.apk
     ├── version.txt
     ├── build_number.txt
     └── build_info.txt
   ```

### Option B — Local build

```bash
# Install Flutter 3.19+ (https://flutter.dev)
flutter pub get
flutter run                      # debug on connected device/emulator
flutter build apk --debug        # build debug APK
# or
flutter build apk --release      # build release APK
```

The APK will be at `build/app/outputs/flutter-apk/app-debug.apk` (or `app-release.apk`).

## Installing on Your Phone

1. Get the APK file (from GitHub Actions artifact or local build).
2. On Android: enable **"Install unknown apps"** for your file manager.
3. Tap the APK to install.
4. Open **Loan Tracker**, grant notification permission when prompted.
5. Create your loan, set a reminder time, paste your first M-Pesa SMS.

## Notifications

- The app requests `POST_NOTIFICATIONS` (Android 13+) and `SCHEDULE_EXACT_ALARM` for exact daily reminders.
- A test notification button is in **Settings → Notifications**.
- Default reminder time is 08:00. Change it in **Settings**.

## PDF Report Export

You can generate a printable PDF report of all transactions for the active loan. The report contains:

- **Loan header** — title, principal, interest rate, start & due dates
- **Totals summary cards** — Total Payable / Total Paid / Balance / Progress %
- **Progress bar** — visual indicator of repayment progress
- **Transaction table** with columns:
  - Date (with time)
  - M-Pesa Code (highlighted if present)
  - Sender / Recipient name
  - Type (M-Pesa or Manual)
  - Amount (Ksh)
- **Totals row** at the bottom of the table
- Page numbers and generation timestamp footer

**How to export:**
- Tap the PDF icon in the top-right of the home screen, **or**
- Go to **Settings → Export & Reports → Generate PDF Report**

The PDF is saved to the app's temp directory and the Android share sheet opens automatically, letting you:
- Save to Files / Downloads
- Send via WhatsApp, Email, Telegram
- Print to a connected printer
- Upload to cloud storage

No internet permission is required — the PDF is generated entirely on-device using the `pdf` package.

## M-Pesa Parser Examples

The parser handles messages like:

```
SI7K2PX1HZ Confirmed. You have sent Ksh500.00 to JOHN DOE 0712345678
on 14/9/26 at 9:30 AM. New M-PESA balance is Ksh1,234.56.
```

```
QFA8H7P2LK Confirmed. Ksh1,200.00 received from JANE DOE 254712345678
on 14/9/26 at 9:30 AM.
```

Supported formats:
- `Ksh`, `KES`, `KSh` (case-insensitive) prefixes for amounts.
- Amounts with thousands separators (`Ksh1,234.56`).
- 2-digit years (`14/9/26`) → 2026.
- 4-digit years (`14/9/2026`).
- AM/PM or 24-hour time.

## Permissions

| Permission | Purpose |
| --- | --- |
| `POST_NOTIFICATIONS` | Show daily reminders (Android 13+) |
| `SCHEDULE_EXACT_ALARM` | Fire reminders at exact time |
| `USE_EXACT_ALARM` | Same, for Android 14+ |
| `RECEIVE_BOOT_COMPLETED` | Re-schedule reminders after device restart |
| `VIBRATE` | Vibrate on notification |
| `WAKE_LOCK` | Wake device to fire reminder |

**No internet permission is requested.** The app is fully offline.

## License

Personal-use. Modify freely.
