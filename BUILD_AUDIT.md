# BUILD AUDIT — loan_tracker / rtrack

> **Read this FIRST before touching any build, gradle, or workflow file.**
> Last verified working: 2026-09-18 (v1.8.0+14)

This document captures the complete audit that produced a working release
APK build. It exists so future agents (human or AI) don't repeat the
piecemeal patch-on-patch cycle that consumed ~25 workflow runs before this
configuration was reached.

---

## 1. THE WORKING TOOLCHAIN (do not change without re-auditing)

| Component | Version | Declared in |
|-----------|---------|-------------|
| Flutter | **3.47.4** (pinned, NOT `channel: stable`) | `.github/workflows/build_apk.yml` line 70 |
| Dart | 3.13.3 (supplied by Flutter 3.47.4) | inherited |
| Java / JDK | **17** (Temurin) | `.github/workflows/build_apk.yml` line 63 |
| Gradle | **8.14.0** | `android/gradle/wrapper/gradle-wrapper.properties` |
| Android Gradle Plugin (AGP) | **8.11.1** | `android/settings.gradle.kts` line 25 |
| Kotlin | **2.2.20** | `android/settings.gradle.kts` line 26 |
| compileSdk | 36 | `android/app/build.gradle.kts` |
| targetSdk | 36 | `android/app/build.gradle.kts` |
| minSdk | 21 | `android/app/build.gradle.kts` |
| Java compat | 17 | `android/app/build.gradle.kts` |
| Kotlin jvmTarget | "17" | `android/app/build.gradle.kts` |

**Why these specific versions:**
- Flutter 3.47.4 is the latest stable at audit time. Pinning (vs `channel: stable`) ensures reproducible builds — `channel: stable` would silently upgrade to 3.48+ on the next run and re-introduce compatibility drift.
- Gradle 8.14.0 is the minimum Flutter 3.47 accepts. Newer Gradle 9.x is NOT yet validated with AGP 8.x; do not upgrade to Gradle 9.
- AGP 8.11.1 is the latest AGP 8.x. AGP 9.x exists but is NOT validated with all our plugins; do not migrate to AGP 9.
- Kotlin 2.2.20 is the minimum Flutter 3.47 accepts. Older Kotlin 1.9.x fails; newer Kotlin 2.3.x is not required.
- Java 17 is the only version AGP 8.x accepts. Java 21 is NOT yet validated.

---

## 1.5 SIGNING STRATEGY — in-place updates without uninstall

Android refuses to install an APK whose signing certificate differs from
the one already installed for the same `applicationId`. Without a stable
signing certificate, every new build would require the user to uninstall
the previous version first.

### How it works

A persistent self-signed keystore is committed to the repo:

| File | Purpose |
|------|---------|
| `android/app/keystore/loan-tracker-release.keystore` | The keystore file (PKCS12, RSA 2048, validity 100 years until 2126) |
| `android/key.properties` | Credentials (storePassword, keyPassword, keyAlias, storeFile path) — committed |

The `android/app/build.gradle.kts` reads `key.properties` at build time
and signs release builds with this keystore. If `key.properties` is
missing (e.g. local dev builds), it falls back to the debug keystore.

### Why we commit the keystore (instead of using GitHub Secrets)

- **Simple**: no secret management, works on any clone
- **Self-signed dev keystore**: not a Play Store upload key, no real value
- **Stable certificate**: every CI build produces an APK with the same
  signing certificate, so Android allows in-place updates
- **If you ever publish to Google Play**: replace this keystore with a
  real upload key stored in GitHub Secrets (NOT committed), and update
  the workflow to read credentials from secrets instead of `key.properties`

### Files that MUST be committed (do NOT gitignore)

```
android/key.properties                                   ✅ committed
android/app/keystore/loan-tracker-release.keystore       ✅ committed
```

The `.gitignore` has explicit exceptions for these paths:
```
!android/key.properties
!android/app/keystore/
!android/app/keystore/*.keystore
```

### Keystore credentials

- **Alias**: `loan-tracker`
- **Store password**: `loantracker123`
- **Key password**: `loantracker123`
- **Validity**: 100 years (until 2126-08-25)

### What an agent must remember

- **Do NOT regenerate the keystore** — a new keystore means a new
  certificate, which means existing installs must be uninstalled.
- **Do NOT gitignore the keystore** — the workflow needs it.
- **Do NOT replace `signingConfig = signingConfigs.getByName("release")`
  with `signingConfigs.getByName("debug")`** in the release buildType —
  that would revert to per-runner ephemeral debug keystores.
- The workflow does NOT need any special step to enable signing — the
  gradle file handles it automatically based on the presence of
  `key.properties`.

---

## 2. WHY PREVIOUS BUILDS FAILED — THE COMPLETE CHAIN

The project went through a sequence of failures, each exposing the next
layer of an inconsistent toolchain. The sequence was NOT random — it was
layers of an old Android/Flutter toolchain being exposed sequentially as
the build progressed farther.

| # | Failure | Root cause | Fix |
|---|---------|------------|-----|
| 1 | `flutter pub get` failed — `home_widget >=0.7.0 requires SDK >=3.4.0` | Workflow used Flutter 3.19.6 (Dart 3.3.4) but pubspec required Dart >=3.4.0 | Pinned Flutter to 3.47.4 in workflow |
| 2 | `flutter analyze` — 8 errors | Source code written against older Flutter/package APIs | Fixed each (see §3 below) |
| 3 | `flutter build apk` — `apply from:` not allowed | Old Groovy gradle files used imperative style | Migrated to declarative `.gradle.kts` files |
| 4 | `flutter build apk` — `compileSdkVersion is not specified` | Auto-generated gradle file stripped compileSdk | Defensive rewrite of `.kts` files in workflow |
| 5 | `flutter build apk` — `Namespace not specified` for `:telephony` | `telephony` 0.2.0 (discontinued) doesn't declare namespace, AGP 8.x requires it | Repository-level namespace injection in `android/build.gradle.kts` `subprojects{}` block |
| 6 | `flutter build apk` — `minifyEnabled` unresolved | Kotlin DSL uses `is` prefix for boolean properties | Changed to `isMinifyEnabled` / `isShrinkResources` |
| 7 | `flutter build apk` — `workmanager` Kotlin compile errors (`ShimPluginRegistry`, `Registrar`, `PluginRegistrantCallback`) | `workmanager` 0.5.2 (discontinued) uses removed Flutter v1 plugin API | Removed `workmanager` from `pubspec.yaml` (it was unused) |
| 8 | `flutter build apk` — `flutter_local_notifications requires core library desugaring` | `flutter_local_notifications` 17.x uses java.time which needs desugaring on Android < 26 | Enabled `isCoreLibraryDesugaringEnabled = true` + added `desugar_jdk_libs` dependency |

---

## 3. ALL SOURCE-CODE FIXES (do not regress)

These 8 source-code fixes are required for `flutter analyze` to pass.
Verify they remain intact before any push.

| # | File | Line | Problem | Fix |
|---|------|------|---------|-----|
| 1 | `lib/screens/home_screen.dart` | ~74 | `Icons.sms_search_outlined` doesn't exist in Flutter Material Icons | Use `Icons.sms_outlined` |
| 2 | `lib/theme/theme.dart` | ~64 | `CardTheme(` not recognized by Flutter 3.27+ | Use `CardThemeData(` (Flutter 3.27+ supports both, but 3.47+ deprecates `CardTheme`) |
| 3 | `lib/widgets/payment_trend_chart.dart` | ~251 | `tooltipBgColor` removed in fl_chart 0.66+ | Use `getTooltipColor: (touchedSpot) => color` |
| 4 | `lib/services/sms_service.dart` | — | `SmsFilter.where.contains()` API mismatch with telephony 0.2.0 | Skip SmsFilter entirely, filter in Dart |
| 5 | `lib/services/sms_service.dart` | — | `Sort.by.desc` — `Sort.by` constant doesn't exist in telephony 0.2.0 | Sort in Dart via `List.sort()` |
| 6 | `lib/services/sms_service.dart` | — | `s.date` is `Object?` not `String?` in telephony 0.2.0 | `_parseDateMillis(dynamic)` helper that accepts any type |
| 7 | `lib/services/notification_service.dart` | — | `zonedSchedule` missing required `uiLocalNotificationDateInterpretation` param | Added `UILocalNotificationDateInterpretation.absoluteTime` |
| 8 | `lib/services/pdf_report_service.dart` | — | `progress` variable declared but unused (became warning after refactor) | Added `// ignore: unused_local_variable` |

**Regression check command:**
```bash
rg -n "sms_search_outlined|tooltipBgColor|Sort\.by|int\.tryParse\(s\.date|int\.tryParse\(sms\.date" lib/
# Should return NOTHING (only comments allowed for SmsFilter.where)
```

---

## 4. ANDROID GRADLE CONFIGURATION — THE THREE `.kts` FILES

The project uses ONLY Kotlin DSL gradle files (`.gradle.kts`).
**No Groovy `.gradle` files should ever be committed.** If both exist,
Flutter 3.32+ tries to auto-migrate the Groovy file and overwrites the
hand-written `.kts` file with a broken auto-generated version.

### 4.1 `android/settings.gradle.kts` — plugin declarations

Key contents:
```kotlin
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}
```

### 4.2 `android/build.gradle.kts` — top-level + namespace injection

This file contains the **permanent fix for the telephony namespace issue**.
The `subprojects {}` block injects a namespace into ANY Android library
plugin that's missing one. This is repository-level (survives clean CI
checkouts), idempotent (only injects if missing), and generic (works for
telephony AND any future legacy plugin with the same issue).

```kotlin
subprojects {
    project.plugins.withId("com.android.library") {
        val androidExtension = project.extensions.getByType(
            com.android.build.gradle.LibraryExtension::class.java
        )
        if (androidExtension.namespace == null || androidExtension.namespace!!.isEmpty()) {
            val group = project.group.toString().trim()
            val namespace = if (group.isNotEmpty() && group != "null") {
                group
            } else {
                val name = project.name.replace("-", "_").replace(".", "_")
                "com.$name"
            }
            androidExtension.namespace = namespace
            logger.lifecycle("[namespace-fix] Injected namespace '$namespace' into project '${project.name}'")
        }
    }
}
```

**Do NOT remove this block** — it's the only thing keeping `telephony`
0.2.0 buildable with AGP 8.x. If you replace telephony with a maintained
alternative, this block becomes a harmless no-op.

### 4.3 `android/app/build.gradle.kts` — app module

Key requirements satisfied by this file:

| Requirement | Plugin that needs it | Code |
|-------------|---------------------|------|
| Core library desugaring | `flutter_local_notifications` 17.x | `isCoreLibraryDesugaringEnabled = true` + `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")` |
| Multidex (speculative) | Any project with 10+ native plugins | `multiDexEnabled = true` |
| Kotlin DSL boolean property naming | Kotlin DSL convention | `isMinifyEnabled`, `isShrinkResources` (NOT `minifyEnabled`, `shrinkResources`) |
| META-INF duplicate exclusion | AGP 8.x strict resource checking | `packaging { resources { excludes += setOf(...) } }` |
| Java 17 compatibility | AGP 8.x requirement | `sourceCompatibility = JavaVersion.VERSION_17` |
| Kotlin JVM target aligned with Java | Kotlin/Java interop | `jvmTarget = "17"` |

---

## 5. CI WORKFLOW — KEY DESIGN PRINCIPLES

`.github/workflows/build_apk.yml` follows these rules:

1. **Pin Flutter to a SPECIFIC version** (`3.47.4`), NOT `channel: stable`.
   `channel: stable` silently upgrades on every run and re-introduces
   compatibility drift.

2. **Defensive cleanup step** (`Remove legacy Groovy gradle files`) deletes
   any stale `*.gradle` files before the build. This guards against the
   case where both `.gradle` and `.gradle.kts` get committed accidentally
   (which causes Flutter to auto-migrate and break).

3. **Static analysis uses `--no-fatal-infos --no-fatal-warnings`** so
   warnings (like `withOpacity is deprecated`) don't block the build.
   Only actual errors block.

4. **No `|| true` hacks** around `flutter build apk`. If the build fails,
   the workflow fails. Hiding failures creates false confidence.

5. **Version auto-bump** is in the workflow (patch+1, build+1) and
   committed back to the repo via `[skip ci]` commit.

---

## 6. NATIVE PLUGIN AUDIT — ALL DEPENDENCIES

Every plugin with native Android code, audited for known requirements:

| Plugin | Version | Status | Special requirements | Satisfied by |
|--------|---------|--------|---------------------|--------------|
| `telephony` | 0.2.0 | ⚠️ discontinued (2022) | Namespace injection | `android/build.gradle.kts` `subprojects{}` block |
| `flutter_local_notifications` | 17.2.2 | ✅ maintained | Core library desugaring | `android/app/build.gradle.kts` |
| `home_widget` | 0.7.0+1 | ✅ maintained | None beyond standard | — |
| `permission_handler` | 11.4.0 | ✅ maintained | POST_NOTIFICATIONS permission | AndroidManifest.xml |
| `sms_autofill` | 2.3.0 | ✅ maintained | None beyond standard | — |
| `share_plus` | 9.0.0 | ✅ maintained | `<queries>` in manifest for Android 11+ | AndroidManifest.xml |
| `sqflite` | 2.4.2+1 | ✅ maintained | None beyond standard | — |
| `url_launcher` | 6.2.6 | ✅ maintained | `<queries>` in manifest | AndroidManifest.xml |
| `path_provider` | 2.1.4 | ✅ maintained | None beyond standard | — |
| `shared_preferences` | 2.2.3 | ✅ maintained | None beyond standard | — |

**Previously removed:**
- `workmanager: ^0.5.2` — discontinued, used removed Flutter v1 plugin API
  (`ShimPluginRegistry`, `Registrar`, `PluginRegistrantCallback`).
  Was declared but never imported in any Dart file. Removed in v1.7.1+12.

---

## 7. REPOSITORY HYGIENE RULES

### 7.1 Files that must NEVER be committed

```
pubspec.lock                          # regenerated by flutter pub get
android/local.properties              # contains machine-specific paths
android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java
                                       # regenerated by Flutter on build
*.keystore, *.jks                     # signing keys
```

These are in `.gitignore`. If they appear in your repo, delete them.

### 7.2 Only ONE gradle file per location

```
android/settings.gradle.kts           ✅ (NOT settings.gradle)
android/build.gradle.kts              ✅ (NOT build.gradle)
android/app/build.gradle.kts          ✅ (NOT app/build.gradle)
```

If both `.gradle` and `.gradle.kts` exist, Flutter 3.32+ tries to
auto-migrate the Groovy file and overwrites the `.kts` file with a
broken auto-generated version. The workflow's `Remove legacy Groovy
gradle files` step guards against this, but the repo should never have
both in the first place.

### 7.3 Stale version reference check

Run this before committing:
```bash
rg -n "3\.19\.6|8\.3\.0|8\.1\.0|1\.9\.10|2\.1\.0" \
  android/ .github/ pubspec.yaml README.md 2>/dev/null
# Should return NOTHING (only historical references in comments are OK)
```

---

## 8. AGENT GUIDANCE — IF THE BUILD BREAKS AGAIN

### 8.1 The #1 rule: DON'T patch piecemeal

If you see a build error, **do NOT immediately fix only that error and
push.** Instead:

1. **Read the FULL error** — what plugin, what file, what API.
2. **Ask: "What's the next layer that will break after I fix this?"**
3. **Audit ALL remaining native plugins** for similar issues.
4. **Fix everything in one commit**, not 5 commits across 5 pushes.

The piecemeal approach consumed ~25 workflow runs. Each run took
~5 minutes. That's 2 hours of wasted CI time because each fix exposed
the next layer without being anticipated.

### 8.2 Common failure patterns and their root causes

| Symptom | Root cause | Fix location |
|---------|-----------|--------------|
| `flutter pub get` fails with SDK constraint | Flutter version too old for pubspec constraints | `.github/workflows/build_apk.yml` — pin specific Flutter version |
| `flutter analyze` — `Icons.X` undefined | Icon name doesn't exist in Flutter Material Icons | Use a real icon name from `Icons` class |
| `flutter analyze` — `CardTheme(` undefined | Flutter 3.27+ renamed to `CardThemeData` | `lib/theme/theme.dart` |
| `flutter analyze` — `tooltipBgColor` undefined | fl_chart 0.66+ removed it | Use `getTooltipColor: (spot) => color` |
| `flutter analyze` — `SmsFilter.where.contains()` fails | telephony 0.2.0 API mismatch | Filter in Dart, don't use SmsFilter |
| `flutter build apk` — `apply from:` not allowed | Old Groovy gradle style | Use `.gradle.kts` with declarative `plugins{}` block |
| `flutter build apk` — `Namespace not specified` for a plugin | Plugin's build.gradle lacks namespace field (AGP 8.x requires it) | `android/build.gradle.kts` `subprojects{}` namespace injection |
| `flutter build apk` — `minifyEnabled` unresolved | Kotlin DSL requires `is` prefix for booleans | Use `isMinifyEnabled`, `isShrinkResources` |
| `flutter build apk` — `ShimPluginRegistry`/`Registrar` unresolved | Plugin uses removed Flutter v1 embedding API | Plugin is discontinued — remove it or replace with maintained alternative |
| `flutter build apk` — `requires core library desugaring` | flutter_local_notifications 17.x uses java.time | `isCoreLibraryDesugaringEnabled = true` + `desugar_jdk_libs` dep |
| `flutter build apk` — `Duplicate class` in androidx.work | Conflicting work-runtime versions | Usually caused by discontinued `workmanager` plugin — remove it |
| `flutter build apk` — `2 files found with path 'META-INF/...'` | AGP 8.x strict duplicate checking | `packaging { resources { excludes += ... } }` |
| `flutter build apk` — `compileSdkVersion is not specified` | Auto-generated gradle file stripped compileSdk | Ensure `.gradle.kts` is the ONLY gradle file (no `.gradle`) |

### 8.3 The speculative audit checklist

Before pushing a build fix, ask:

- [ ] Does any remaining native plugin use the Flutter v1 embedding API
      (`ShimPluginRegistry`, `Registrar`, `PluginRegistrantCallback`)?
      Check the plugin's `android/src/main/kotlin/` for these references.
- [ ] Does any remaining native plugin require core library desugaring?
      Check the plugin's pub.dev README for "desugaring".
- [ ] Does any remaining native plugin declare a namespace?
      If not, the `subprojects{}` injection handles it automatically.
- [ ] Are there any duplicate META-INF resources?
      The `packaging.resources.excludes` block handles common ones.
- [ ] Are all Kotlin DSL boolean properties using the `is` prefix?
      (`isMinifyEnabled`, `isShrinkResources`, `isDebuggable`, etc.)
- [ ] Is the Flutter version pinned (not `channel: stable`)?
- [ ] Are there any stale `.gradle` files alongside `.gradle.kts` files?

### 8.4 How to verify the build locally (if Flutter is installed)

```bash
flutter clean
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter build apk --release

# Verify the toolchain versions:
cd android && ./gradlew --version   # should show Gradle 8.14.0
java -version                        # should show Java 17
flutter --version                    # should show Flutter 3.47.4
```

### 8.5 What NOT to do

- **Do NOT use `channel: stable`** for Flutter in the workflow — it
  silently upgrades and re-introduces drift.
- **Do NOT use `|| true`** around `flutter build apk` to hide failures.
- **Do NOT migrate to AGP 9** — not yet validated with all plugins.
- **Do NOT migrate to Gradle 9** — not yet validated with AGP 8.x.
- **Do NOT downgrade Kotlin** below 2.2.20 — Flutter 3.47 rejects it.
- **Do NOT downgrade Java** below 17 — AGP 8.x rejects it.
- **Do NOT commit `pubspec.lock`** — it pins stale versions.
- **Do NOT commit `GeneratedPluginRegistrant.java`** — Flutter regenerates it.
- **Do NOT have both `.gradle` and `.gradle.kts` files** — Flutter
  auto-migrates and breaks.
- **Do NOT patch the pub-cache** in CI — it disappears on every clean
  checkout. Use repository-level fixes (like the `subprojects{}` namespace
  injection in `android/build.gradle.kts`).

---

## 9. CHANGELOG OF AUDIT FIXES (v1.8.0+14)

| Version | Change |
|---------|--------|
| v1.0.0+1 | Initial project |
| v1.1.0+2 | PDF export + transactions table |
| v1.2.0+3 | Home widget + trend chart + SMS auto-import |
| v1.3.0+4 | Lender contact + receipts + monthly statements + multiple reminders |
| v1.4.0+5 | First rebuild: new `build_apk.yml`, missing gradle files added |
| v1.5.0+6 | Self-healing workflow (defensive gradle file writes) |
| v1.5.1+7 | Fixed `CardTheme` → `CardThemeData` for Flutter 3.27 |
| v1.6.0+8 | Complete toolchain audit; pinned Flutter 3.27.0 |
| v1.6.1+9 | Fixed Kotlin DSL `isMinifyEnabled` / `isShrinkResources` |
| v1.6.2+10 | Added telephony namespace patching (pub-cache, later superseded) |
| v1.7.0+11 | **Major audit**: AGP 8.11.1, Kotlin 2.2.20, Flutter 3.47.4, repo-level namespace injection in `android/build.gradle.kts` |
| v1.7.1+12 | Removed discontinued `workmanager` 0.5.2 (unused, used removed Flutter v1 API) |
| v1.7.2+13 | **Speculative audit**: enabled core library desugaring, multidex, META-INF excludes — **BUILD SUCCEEDED** |
| v1.8.0+14 | **Persistent signing keystore**: committed `loan-tracker-release.keystore` + `key.properties` so consecutive builds share the same certificate (enables in-place updates without uninstall) |

---

## 10. SUCCESS CONDITION

A build is successful when ALL of the following are true:

- [ ] `flutter analyze --no-fatal-infos --no-fatal-warnings` exits 0
- [ ] `flutter build apk --release` completes without errors
- [ ] APK artifact is uploaded to the workflow run
- [ ] Version bump commit is pushed back to the repo
- [ ] No `|| true` or `--android-skip-build-dependency-validation` hacks
- [ ] Toolchain versions match §1 exactly

If any of these fail, return to §8 and re-audit.
