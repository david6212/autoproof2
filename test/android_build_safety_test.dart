import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Two ways the Android build can hand something away quietly.
///
/// Neither has a runtime surface, so neither can be caught by using the app.
/// They are caught here or after the fact — and this project has already paid
/// for one of them once: a release signed with the debug key, in which phone
/// auth and Google Sign-In were dead for weeks.
void main() {
  group('a release build is signed with the release key or not at all', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    test('a missing key.properties stops the build instead of substituting', () {
      // The fallback produced a file named app-...-release.apk that installs,
      // runs, and can never update an installed BonnetCheck, because Android
      // refuses an update signed with a different key. The build log said
      // nothing. A fresh clone, another machine or CI all hit it.
      expect(gradle, contains('GradleException'));
      expect(gradle.contains('if (hasReleaseKey) "release" else "debug"'),
          isFalse,
          reason: 'that is the silent substitution itself');
    });

    test('and a keyless build is still possible, but only on purpose', () {
      // CI smoke builds are a real need. The difference that matters is that
      // somebody typed the flag.
      expect(gradle, contains('allowDebugSigning'));
    });

    test('a debug build on a fresh clone still works', () {
      // The guard has to fire when a release artefact is being produced, not
      // whenever Gradle configures the project — `buildTypes { release { } }`
      // is evaluated even for `flutter run`, so throwing unconditionally
      // would stop anyone without key.properties from running the app at all.
      expect(gradle, contains('startParameter'));
    });
  });

  group("the phone's copy of a signed-in session stays on the phone", () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    /// The attributes of the `<application>` element, and nothing else — an
    /// attribute on the wrong element is not an attribute.
    final application = manifest.substring(
      manifest.indexOf('<application'),
      manifest.indexOf('>', manifest.indexOf('<application')),
    );

    test('backup is off, rather than left at its default', () {
      // Unset means true. Firebase Auth keeps its refresh token in the app's
      // private data directory, so the default copies a signed-in session
      // into the user's Google account and restores it onto a new device.
      // There is nothing on the device worth restoring — everything real is
      // in Firestore.
      expect(application, contains('android:allowBackup="false"'));
      expect(application, contains('android:fullBackupContent="false"'));
    });

    test('including the device-to-device transfer, which allowBackup misses',
        () {
      // For an app targeting Android 12 or higher, allowBackup="false" stops
      // the cloud backup but not a D2D transfer; that half is governed by
      // dataExtractionRules. targetSdk here is 36, so without the rules file
      // the session still rides across to the new handset.
      expect(application, contains('android:dataExtractionRules='));

      final rules =
          File('android/app/src/main/res/xml/data_extraction_rules.xml');
      expect(rules.existsSync(), isTrue);
      final text = rules.readAsStringSync();
      expect(text, contains('<cloud-backup>'));
      expect(text, contains('<device-transfer>'));
      // Excluded everywhere it can be named: the point is that nothing
      // leaves, not that one directory does not.
      expect(text.split('<exclude').length - 1, greaterThanOrEqualTo(8));
    });
  });
}
