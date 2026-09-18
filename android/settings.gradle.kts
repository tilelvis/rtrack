// Top-level Flutter settings.gradle.kts (declarative plugins{} block).
// Required by Flutter 3.16+ and enforced by Flutter 3.47+.
// The old imperative `apply from:` style is no longer supported.
//
// TOOLCHAIN (audited 2026-09-18):
//   Flutter 3.47.4
//   Dart   3.13.3
//   Java   17
//   Gradle 8.14.0
//   AGP    8.11.1
//   Kotlin 2.2.20
// These versions are confirmed mutually compatible per Flutter 3.47 release
// notes (https://docs.flutter.dev/release/release-notes) and AGP 8.x
// compatibility matrix (https://developer.android.com/build/releases/gradle-plugin).

pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
