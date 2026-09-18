// Android app module build configuration (Kotlin DSL, declarative plugins{}).
// Versioning: code (integer) = build number, name (string) = semantic version.
// Both are injected from pubspec.yaml by Flutter at build time.

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
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
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
    }

    buildTypes {
        release {
            // Sign release with the debug keystore so the APK installs on a phone
            // without needing a separate upload key. Replace with a real keystore
            // before publishing to Play Store.
            signingConfig = signingConfigs.getByName("debug")
            minifyEnabled = false
            shrinkResources = false
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
