import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What the Android build asks the phone for.
///
/// Two of these are removals, and a removal is easy to lose: it only exists
/// while a `tools:node="remove"` line survives in the manifest, and the SDK
/// that adds them back ships a new version every few weeks.
void main() {
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  test('the advertising ID is removed, not merely unused', () {
    // Firebase Analytics merges these in on its own, and a built APK declared
    // all three — while the privacy policy says outright that the service
    // carries no advertising or ad-tracking networks, and Play's Data Safety
    // form asks about the advertising ID as its own question.
    for (final permission in [
      'com.google.android.gms.permission.AD_ID',
      'android.permission.ACCESS_ADSERVICES_ATTRIBUTION',
      'android.permission.ACCESS_ADSERVICES_AD_ID',
    ]) {
      final at = manifest.indexOf(permission);
      expect(at, greaterThan(-1), reason: '$permission is no longer removed');
      final line = manifest.substring(at, manifest.indexOf('/>', at));
      expect(line.contains('tools:node="remove"') ||
              manifest.substring(at, at + 220).contains('tools:node="remove"'),
          isTrue,
          reason: '$permission is declared without being removed');
    }
    expect(manifest, contains('xmlns:tools='),
        reason: 'tools:node needs the namespace or the merge fails');
  });

  test('location stays coarse', () {
    // The feature is "which inspection centre is nearest", answered at
    // city-block resolution. FINE is a stronger claim on somebody's
    // whereabouts than that question needs.
    expect(manifest, contains('android.permission.ACCESS_COARSE_LOCATION'));
    expect(manifest.contains('ACCESS_FINE_LOCATION'), isFalse);
  });

  test('nothing asks to read or write storage', () {
    // Documents are picked through the system picker, which needs no
    // permission, and there is nothing to write to the gallery.
    for (final gone in [
      'READ_EXTERNAL_STORAGE',
      'WRITE_EXTERNAL_STORAGE',
      'READ_MEDIA_IMAGES',
      'CAMERA',
    ]) {
      expect(manifest.contains(gone), isFalse, reason: gone);
    }
  });
}
