import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // google-services-Plugin bewusst NICHT angewandt (optionsbasierte Firebase-Init).
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release-Signing: lädt android/key.properties (nicht im Git eingecheckt).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.jass.jass_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.jass.jass_app"
        // Firebase (core/analytics) verlangt minSdk 23.
        minSdk = maxOf(23, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Standard-App-Name (Release). Debug überschreibt ihn unten.
        manifestPlaceholders["appLabel"] = "Jass"
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        debug {
            // Eigene Package-ID + Name → installiert sich getrennt neben der
            // echten (Play-Store-)App, kein Konflikt/Crash beim Testen.
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appLabel"] = "Jass DEV"
        }
        release {
            // Echte Release-Signatur (Upload-Key), fällt auf Debug zurück falls
            // key.properties fehlt (z.B. CI ohne Secrets) — dann kein Store-Upload.
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// Kotlin 2.4+ : jvmTarget über die neue compilerOptions-DSL (kotlinOptions entfernt).
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
