import java.util.Properties

// Release signing details live outside the repo, in android/key.properties.
// Absent (a fresh clone, CI, another machine) the build falls back to the
// debug key so nothing breaks — it just can't produce a distributable APK.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "il.autoproof.autoproof"
    // Pinned, not inherited. Google Play stops accepting a FIRST submission
    // below API 36 on 31/08/2026, and the installed Flutter's default is 35 —
    // so inheriting it would have failed at upload with no warning in the
    // repo. An extension to 01/11/2026 can be requested, but a request is not
    // an entitlement.
    compileSdk = 36
    // Firebase plugins require this NDK version.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "il.autoproof.autoproof"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Firebase Auth requires minSdk 23.
        minSdk = 23
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // An APK anyone installs must be signed with the release key: the
            // signature is the app's identity, and an update signed with a
            // different key is refused by Android. Losing this keystore means
            // never being able to update the installed app.
            signingConfig = signingConfigs.getByName(
                if (hasReleaseKey) "release" else "debug"
            )
        }
    }
}

flutter {
    source = "../.."
}
