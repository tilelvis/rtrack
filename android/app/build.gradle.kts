// Android app module build configuration (Kotlin DSL, declarative plugins{}).
// Versioning: code (integer) = build number, name (string) = semantic version.
// Both are injected from pubspec.yaml by Flutter at build time.
//
// TOOLCHAIN (audited 2026-09-18):
//   Flutter 3.47.4
//   Dart   3.13.3
//   Java   17
//   Gradle 8.14.0
//   AGP    8.11.1
//   Kotlin 2.2.20
//
// Plugin-specific requirements satisfied by this file:
//   - flutter_local_notifications 17.x: requires core library desugaring
//     (https://pub.dev/packages/flutter_local_notifications#android-manifest)
//   - All other native plugins: standard config, no special requirements

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied AFTER android & kotlin.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.loan_tracker"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Java 17 — required by AGP 8.x and matches the workflow's JDK.
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        // ----------------------------------------------------------------
        // Core library desugaring — REQUIRED by flutter_local_notifications
        // 17.x for java.time usage on older Android versions (API < 26).
        // Without this, the build fails with:
        //   "Dependency ':flutter_local_notifications' requires core library
        //    desugaring to be enabled for :app."
        // ----------------------------------------------------------------
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        // Align Kotlin JVM target with Java 17.
        jvmTarget = "17"
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        applicationId = "com.example.loan_tracker"
        minSdk = 21
        targetSdk = 36
        versionCode = flutter.versionCode.toInt()
        versionName = flutter.versionName

        // ----------------------------------------------------------------
        // Multidex — enable speculatively. With the number of native plugins
        // in this project (flutter_local_notifications, permission_handler,
        // telephony, home_widget, sms_autofill, share_plus, sqflite,
        // url_launcher, path_provider, shared_preferences), the 64K method
        // limit can be hit on minSdk < 21 builds. We use minSdk 21 so
        // Android handles multidex natively, but this flag is the safe
        // belt-and-braces setting recommended by AGP 8.x docs.
        // ----------------------------------------------------------------
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Sign release with the debug keystore so the APK installs on a phone
            // without needing a separate upload key. Replace with a real keystore
            // before publishing to Play Store.
            signingConfig = signingConfigs.getByName("debug")
            // Kotlin DSL uses `is` prefix for boolean Gradle properties
            // (Groovy silently translates, Kotlin is strict).
            isMinifyEnabled = false
            isShrinkResources = false
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // ----------------------------------------------------------------
    // packagingOptions — exclude duplicate META-INF files that some
    // plugins (e.g. kotlin-stdlib, kotlinx-coroutines) ship. Without
    // these exclusions, AGP 8.x fails with:
    //   "2 files found with path 'META-INF/...'"
    // This is a speculative fix for any plugin that might trigger this.
    // ----------------------------------------------------------------
    packaging {
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/license.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/notice.txt",
                "META-INF/ASL2.0",
                "META-INF/AL2.0",
                "META-INF/LGPL2.1",
                "META-INF/*.kotlin_module",
                "META-INF/INDEX.LIST",
            )
        }
    }
}

flutter {
    source = "../.."
}

// ----------------------------------------------------------------------------
// Dependencies required by core library desugaring.
// flutter_local_notifications 17.x pulls in java.time which needs desugaring
// on Android < 26 (we support minSdk 21).
// ----------------------------------------------------------------------------
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // multidex is provided by AndroidX on minSdk >= 21, no explicit dep needed
}
