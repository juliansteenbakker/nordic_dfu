group = "dev.steenbakker.nordicdfu"
version = "1.0-SNAPSHOT"

plugins {
    id("com.android.library")
}

// AGP 9 supplies Kotlin support itself, so applying the Kotlin plugin here would
// conflict with it. Apps on older Flutter versions still build this plugin with
// AGP 8, where the Kotlin plugin has to be applied explicitly.
// https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-plugin-authors
val agpMajor = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION.substringBefore('.').toInt()
if (agpMajor < 9) {
    apply(plugin = "org.jetbrains.kotlin.android")
}

android {
    namespace = "dev.steenbakker.nordicdfu"

    compileSdk = 36

    defaultConfig {
        minSdk = 18
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

// Replaces the removed `kotlinOptions` block. It is configured through
// `extensions` instead of a `kotlin { }` block because the Kotlin extension only
// exists once something has applied the Kotlin plugin, which happens at
// different points depending on the AGP and Flutter version in the host app.
fun setKotlinJvmTarget() {
    extensions.configure(org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension::class.java) {
        compilerOptions {
            jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        }
    }
}

if (extensions.findByName("kotlin") != null) {
    setKotlinJvmTarget()
} else {
    // AGP 9 with built-in Kotlin disabled: the Flutter Gradle Plugin applies the
    // Kotlin plugin to this project later on.
    plugins.withId("org.jetbrains.kotlin.android") { setKotlinJvmTarget() }
}

dependencies {
    implementation("no.nordicsemi.android:dfu:2.11.0")
}
