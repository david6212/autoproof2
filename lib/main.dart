import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/utils/release_error_widget.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Before anything can build, so a failure during startup is reported too.
  ReleaseErrorWidget.install();
  _registerFontLicences();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Off before the first frame, and before anything can ask for a screen
  // view. The stored answer is read a moment later by
  // `analyticsConsentProvider`, which turns it back on only if the reader
  // has said yes. Doing it in this order means a cold start measures nothing
  // while the answer is still being loaded.
  //
  // NOT on the web, and this is the opposite of an oversight: on the web,
  // *touching* FirebaseAnalytics is what pulls `gtag.js` down from Google.
  // Measured on the live site — the call meant to disable measurement was
  // itself the request to Google's server. There, nothing initialises
  // analytics until consent is granted.
  if (!kIsWeb) {
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false);
    } catch (_) {
      // Never let a measurement toggle stop the app from starting.
    }
  }

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
