// Top-level Android build file (Kotlin DSL).
// All plugin declarations live in settings.gradle.kts.

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// ----------------------------------------------------------------------------
// REPOSITORY-LEVEL NAMESPACE INJECTION FOR LEGACY ANDROID LIBRARY PLUGINS
// ----------------------------------------------------------------------------
// Android Gradle Plugin 8.x requires every Android library module to declare
// a `namespace` in its build.gradle. Most maintained plugins already do.
// However, the project depends on `telephony` 0.2.0 (discontinued 2022)
// which does not. Rather than patching the pub-cache (which disappears on
// every clean CI checkout), we inject a namespace here, at the Gradle
// configuration level, for any library plugin that's missing one.
//
// This is deterministic, idempotent, and survives clean checkouts.
// If a future dependency switch removes telephony, this block simply
// becomes a no-op for all maintained plugins.
//
// The namespace is derived from the plugin's declared `group` (which is
// typically the Java package reverse-DNS form), falling back to
// `com.<plugin_name>` if no group is declared.
// ----------------------------------------------------------------------------
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
                // Derive from project name (e.g. "telephony" -> "com.telephony")
                val name = project.name.replace("-", "_").replace(".", "_")
                "com.$name"
            }
            androidExtension.namespace = namespace
            logger.lifecycle("[namespace-fix] Injected namespace '$namespace' into project '${project.name}'")
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
