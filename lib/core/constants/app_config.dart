/// Runtime capabilities that depend on how the Firebase project is set up,
/// rather than on anything in this codebase.
class AppConfig {
  AppConfig._();

  /// Whether Firebase Storage is provisioned on the project.
  ///
  /// **It is not.** `autoproof-8d827` has never had a Cloud Storage bucket —
  /// `firebase deploy --only storage` fails with "Storage has not been set up",
  /// and provisioning the first bucket needs the Blaze plan.
  ///
  /// **Passport documents no longer wait for it.** Their bytes go into a
  /// Firestore document instead — see [DocumentRepository] — which works on
  /// the free plan today and, as a side effect, makes unsharing an actual
  /// revocation. What still depends on this flag is **listing photos** and
  /// **service receipts**: both fail at the network call while it is false.
  ///
  /// This flag exists so the app can say that instead of discovering it. A
  /// button that always fails is worse than a button that is not there: the
  /// user blames themselves, tries again, and learns not to trust the feature.
  /// With this false, the upload controls are replaced by one honest line.
  ///
  /// **To turn file uploads on:** enable Storage in the Firebase console
  /// (location `eur3`, matching Firestore), run
  /// `firebase deploy --only storage` to publish `storage.rules`, then flip
  /// this to `true`. Nothing else needs changing — the upload code is written,
  /// tested and waiting.
  static const storageEnabled = false;

  /// Whether "המשך עם Apple" can actually sign anyone in.
  ///
  /// **It cannot.** The button needs the Apple provider enabled in the Firebase
  /// console, and that needs a paid Apple Developer account, which this project
  /// does not have. It was on screen unconditionally — on Android and in the
  /// browser, where it is not even the platform convention — so a visitor met
  /// two failing routes (this and phone verification) before reaching the one
  /// that works.
  ///
  /// Same rule as [storageEnabled], and it is written out one flag above: a
  /// button that always fails is worse than a button that is not there.
  ///
  /// **To turn it on:** enable Apple as a sign-in provider in Firebase Auth,
  /// register the Service ID and key from the Apple Developer account, and
  /// flip this. `signInWithApple()` is written and waiting. Apple also requires
  /// its own logo artwork — drawing an approximation is a guideline breach.
  static const appleSignInEnabled = false;

  /// The one sentence shown wherever a file could have been attached.
  static const uploadsUnavailable =
      'צירוף קבצים אינו זמין כרגע. שאר הפרטים נשמרים כרגיל.';

  /// The released version, quoted in support enquiries.
  ///
  /// A duplicate of `version:` in pubspec.yaml, because reading the real one
  /// needs `package_info_plus` and a whole plugin is a steep price for one
  /// string. `app_version_test` reads pubspec and fails if the two drift — a
  /// version number that lies is worse than none, since it sends support
  /// looking at the wrong build.
  static const appVersion = '0.8.0+8';
}
