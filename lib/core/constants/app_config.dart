/// Runtime capabilities that depend on how the Firebase project is set up,
/// rather than on anything in this codebase.
class AppConfig {
  AppConfig._();

  /// Whether Firebase Storage is provisioned on the project.
  ///
  /// **It is not.** `autoproof-8d827` has never had a Cloud Storage bucket —
  /// `firebase deploy --only storage` fails with "Storage has not been set up",
  /// and provisioning the first bucket needs the Blaze plan. So every upload
  /// path in the app — listing photos, service receipts, passport documents —
  /// fails at the network call.
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
  static const appVersion = '0.5.0+5';
}
