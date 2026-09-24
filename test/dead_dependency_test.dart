import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A dependency nothing imports still ships.
///
/// `flutter_secure_storage` was declared from the very first pubspec and never
/// used by a single line: the only hit for it anywhere in `lib/` or `test/`
/// was the declaration itself. It is not inert — it pulls a Keystore /
/// Keychain / libsecret / DPAPI implementation and five platform plugins into
/// every build, and the generated plugin registrants named it on Android and
/// iOS, so the native surface was in the published APK.
///
/// Dead dependencies are the ones nobody upgrades and nobody notices a CVE in,
/// because no code path leads near them. This one was also two majors behind.
///
/// If secure storage is wanted later — to stop leaning on SharedPreferences,
/// say — it comes back at 11.x, deliberately, with something using it.
void main() {
  test('flutter_secure_storage is gone from the manifest and the lockfile', () {
    // The declaration, not the word: the comment left in its place names it
    // on purpose, so that re-adding it is a decision rather than a reflex.
    final declared = File('pubspec.yaml')
        .readAsLinesSync()
        .any((l) => l.trimLeft().startsWith('flutter_secure_storage:'));
    expect(declared, isFalse);
    expect(File('pubspec.lock').readAsStringSync().contains('secure_storage'),
        isFalse,
        reason: 'still resolved, so still built');
  });

  test('and nothing in the app was relying on it', () {
    // The check that makes the removal safe rather than merely tidy. It runs
    // on every build from now on, so a future import cannot quietly reinstate
    // a dependency that is no longer declared.
    for (final dir in [Directory('lib'), Directory('test')]) {
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        if (f.path.endsWith('dead_dependency_test.dart')) continue;
        expect(f.readAsStringSync().contains('FlutterSecureStorage'), isFalse,
            reason: f.path);
      }
    }
  });
}
