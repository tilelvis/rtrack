# RTrack Repair Report

## Implemented

- Replaced the unsafe `afterEvaluate` Android Gradle workaround with a plugin-application-time `LibraryExtension` namespace configuration for the legacy `telephony` 0.2.0 module. This directly addresses the CI `Namespace not specified` failure without relying on `afterEvaluate`.
- Kept the existing Flutter/AGP/Kotlin toolchain unchanged rather than hiding the failure with a downgrade.
- Raised the app `compileSdk` and `targetSdk` from 34 to 36 to satisfy current Flutter plugin requirements reported by CI (`shared_preferences_android` and `sqflite_android`).
- Added SQLite `PRAGMA foreign_keys = ON` on every opened database connection.
- Added a partial unique index for non-null M-Pesa transaction codes.
- Added database migration v3 -> v4 that removes duplicate legacy M-Pesa-code rows before creating the unique index.
- Made M-Pesa insertion idempotent for repeated imports of the same transaction.
- Prevented an M-Pesa transaction already assigned to another loan from being silently duplicated.
- Removed the `DateTime.now()` fallback from M-Pesa parsing.
- Added strict calendar-date validation because Dart `DateTime` normalizes invalid dates rather than throwing.
- Hardened amount parsing for common sent and received Safaricom message forms.
- Normalized transaction codes to uppercase.
- Updated SMS import and paste flows to handle cross-loan duplicate transactions without crashing the UI.
- Added parser regression tests.
- Added exact-alarm permission requesting and removed redundant `USE_EXACT_ALARM`; scheduled reminders use `SCHEDULE_EXACT_ALARM` with an explicit request flow.

## Verification limitation

The supplied execution environment does not contain the Flutter/Dart SDK, so `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build apk --release` could not be executed here. The source was statically inspected and the requested fixes were applied. The final ZIP therefore must be validated in a Flutter-capable environment/CI before treating the APK build as verified.


## Follow-up CI diagnosis

The next CI run after the first repair failed with:

```text
A problem occurred configuring project ':telephony'.
Namespace not specified ... telephony-0.2.0/android/build.gradle
```

The first repair removed the old namespace workaround but did not replace it. The current repair restores the required namespace using the supported Android Gradle plugin extension callback instead of `afterEvaluate`.

CI also reported that `shared_preferences_android` and `sqflite_android` require Android SDK 36 or higher. The app module now uses compile/target SDK 36.
