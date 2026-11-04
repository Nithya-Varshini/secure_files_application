import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing comes from android/key.properties, which is git-ignored and
// points at the upload keystore. See docs/RELEASING.md.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.nithya.privacyvault"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        // Lets each build type set its own app name (see resValue below).
        resValues = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Permanent once published on Google Play.
        applicationId = "com.nithya.privacyvault"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // From pubspec.yaml: version: <versionName>+<versionCode>
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resValue("string", "app_name", "Kwam")
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        debug {
            // Installs beside the release app: com.nithya.privacyvault.dev
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "Kwam Dev")
        }
        release {
            // Flutter already turns on R8 code shrinking for release builds.
            // Without key.properties, fall back to debug keys so
            // `flutter run --release` still works locally; such a build cannot
            // be uploaded to Google Play.
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // AppCompat launch theme: BiometricPrompt (local_auth) crashes on
    // Android 8 and below without it.
    implementation("androidx.appcompat:appcompat:1.7.0")
}
