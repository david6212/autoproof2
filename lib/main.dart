import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicences();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: BonnetCheckApp()));
}

/// Puts the bundled fonts' licences into the "licenses" page Flutter builds.
///
/// Heebo and Poppins ship inside the app now rather than being downloaded from
/// Google at first paint. Both are SIL Open Font License 1.1, which requires
/// the licence to travel with the font — a package would have registered it
/// for us, and bundling the files by hand moves that duty here.
void _registerFontLicences() {
  LicenseRegistry.addLicense(() async* {
    for (final entry in const {
      'Heebo': 'assets/fonts/OFL-Heebo.txt',
      'Poppins': 'assets/fonts/OFL-Poppins.txt',
    }.entries) {
      yield LicenseEntryWithLineBreaks(
        [entry.key],
        await rootBundle.loadString(entry.value),
      );
    }
  });
}
