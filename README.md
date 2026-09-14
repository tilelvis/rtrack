# Loan Tracker

A personal loan repayment tracker for Android, built with **Flutter (Dart)** and **Material 3**. Designed for tracking a single short-term loan (e.g. a 30-day loan payable in weekly or custom-interval installments), recording M-Pesa payment messages, and reminding you daily to make a payment.

## Features

- **Loan setup** — principal, interest rate, start/due dates, weekly or custom-day payment interval, expected amount per interval.
- **Dashboard** — progress ring, balance remaining, days left, "today paid?" status.
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
│   │   └── notification_service.dart # Daily reminders
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
│       └── payment_history_list.dart
├── pubspec.yaml               # version: 1.0.0+1  (semantic + build)
├── analysis_options.yaml
└── README.md
```

## Versioning

The app uses **both** semantic version and build number, in the form `MAJOR.MINOR.PATCH+BUILD` (e.g. `1.0.0+1`).

- `version` field in `pubspec.yaml` is the single source of truth.
- `versionCode` (Android integer) = build number.
- `versionName` (Android string) = semantic version.

On every GitHub Actions run, the workflow:
1. Reads current `version: X.Y.Z+N` from `pubspec.yaml`.
2. Accepts optional `version` and `build_number` inputs.
3. If inputs are empty, keeps current version and auto-increments build number.
4. Validates the semantic version regex `^[0-9]+\.[0-9]+\.[0-9]+$`.
5. Updates `pubspec.yaml` with the new `version` line.
6. Builds the APK with `--build-name` and `--build-number` flags.
7. Commits the bumped `pubspec.yaml` back to the repo.

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
