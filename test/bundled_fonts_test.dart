import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The fonts ship with the app; they are not fetched at first paint.
///
/// `google_fonts` downloaded Heebo and Poppins from Google's servers the first
/// time the app painted, which sent every reader's IP address to a third party
/// before anything was on screen, disclosed to nobody. That is the fact
/// pattern of LG München I, 3 O 17493/20. The landing site had already been
/// self-hosting its copies for months; only the app leaked.
void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();

  test('the runtime font fetcher is gone', () {
    expect(pubspec.contains('google_fonts'), isFalse);

    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.readAsStringSync().contains('GoogleFonts')) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty);
  });

  test('both families are declared and their files are really there', () {
    for (final asset in const [
      'assets/fonts/Heebo-Regular.ttf',
      'assets/fonts/Heebo-SemiBold.ttf',
      'assets/fonts/Heebo-Bold.ttf',
      'assets/fonts/Poppins-Bold.ttf',
    ]) {
      expect(pubspec, contains(asset));
      final f = File(asset);
      expect(f.existsSync(), isTrue, reason: '$asset is declared but missing');
      // A TrueType file starts 00 01 00 00. Google's CSS endpoint will serve
      // EOT to an old User-Agent, and an EOT named .ttf fails silently at
      // runtime by falling back to the default font.
      final head = f.readAsBytesSync().sublist(0, 4);
      expect(head, [0, 1, 0, 0], reason: '$asset is not TrueType');
    }
  });

  test('the OFL text travels with the fonts', () {
    // The licence requires it, and nothing registers it for us now that the
    // package is gone.
    for (final licence in const [
      'assets/fonts/OFL-Heebo.txt',
      'assets/fonts/OFL-Poppins.txt',
    ]) {
      expect(File(licence).existsSync(), isTrue);
      expect(File(licence).readAsStringSync(),
          contains('SIL OPEN FONT LICENSE'));
    }
    expect(File('lib/main.dart').readAsStringSync(),
        contains('LicenseRegistry.addLicense'));
  });
}
