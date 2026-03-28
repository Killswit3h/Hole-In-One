pluginManagement {
    val flutterSdkPath: String by run {
        val properties = java.util.Properties()
        val localPropertiesFile = file("local.properties")
        if (localPropertiesFile.exists()) {
            localPropertiesFile.inputStream().use { properties.load(it) }
        }
        val path = properties.getProperty("flutter.sdk")
            ?: System.getenv("FLUTTER_ROOT")
            ?: error(
                "Flutter SDK not found. Set flutter.sdk in android/local.properties " +
                "or set the FLUTTER_ROOT environment variable."
            )
        extra["flutterSdkPath"] = path
        path
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
    id("com.android.application") version "8.3.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.22" apply false
}

include(":app")
