import java.util.Properties

// Release signing details live outside the repo, in android/key.properties.
// Absent (a fresh clone, CI, another machine) a release build used to fall
// back to the debug key and say nothing about it. See the release block below:
// it now stops instead.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null

// Whether this invocation is actually producing a release artefact.
//
// `buildTypes { release { } }` is configured on every Gradle run, `flutter
// run` included, so a guard that throws there unconditionally would stop
// anyone without key.properties from even starting the app. The guard has to
// know what is being built.
val buildingRelease =
    gradle.startParameter.taskNames.any { it.contains("Release") }

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
            //
            // The substitution this used to make was the dangerous part. A
            // machine without key.properties produced a file named
            // app-...-release.apk, signed with the debug key, that installs,
            // runs, and can never update an installed BonnetCheck — and the
            // build log said nothing. This project has already paid for a
            // debug-signed release once: phone auth and Google Sign-In were
            // dead in it for weeks, and nobody could tell from the artefact.
            if (hasReleaseKey) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                if (buildingRelease && !project.hasProperty("allowDebugSigning")) {
                    throw GradleException(
                        "No android/key.properties, so this release would be " +
                        "signed with the DEBUG key. Android refuses an update " +
                        "signed with a different key, so the APK would install " +
                        "but could never update an installed BonnetCheck. " +
                        "Restore android/key.properties, or pass " +
                        "-PallowDebugSigning=true for a throwaway build that " +
                        "must never be published."
                    )
                }
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
