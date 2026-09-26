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

  /// Whether "ליווי מקצועי לבדיקה" is offered at all — the directory of people
  /// who will come with a buyer to look at a car, for a price they set.
  ///
  /// **Off, and waiting for a lawyer's answer, not for code.** The screens,
  /// the model, the repository and the rules are written and tested. What is
  /// not settled is whether paid accompaniment makes this app a broker or an
  /// inspection institute under the vehicle-trade licensing law, and what the
  /// operator's exposure is to a professional's opinion. Both questions are in
  /// `docs/legal-meeting/2026-09-17-lawyer-brief` as questions 10 and 11.
  ///
  /// Same rule as the three flags above: a route that cannot honestly run is
  /// better absent than present. Here the reason is legal rather than
  /// technical, which makes it a stronger reason, not a weaker one.
  ///
  /// **To turn it on:** get the answer, apply whatever wording it requires,
  /// deploy the rules (`firebase deploy --only firestore:rules`) and flip
  /// this. The rules ship deployed either way — a collection with no rules is
  /// a collection with no protection the day somebody flips a flag.
  static const escortEnabled = false;

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

  /// Whether the phone / SMS sign-in route is offered at all.
  ///
  /// **Off, because it cannot succeed.** Firebase phone auth needs the Blaze
  /// plan; on Spark every send fails with `BILLING_NOT_ENABLED`. The failure
  /// is handled honestly — `auth_repository` maps it to a message that blames
  /// the operator rather than the user — but a route that always fails is
  /// still a route that always fails, and Play reviewers test sign-in.
  ///
  /// Same rule as [appleSignInEnabled] and [storageEnabled], applied to the
  /// third and last failing route: a button that always fails is worse than a
  /// button that is not there.
  ///
  /// **To turn it on:** enable Blaze, confirm Phone is on as a Firebase Auth
  /// provider, and flip this. The whole flow — `sendCode`, `verifyCode`, the
  /// resend timer, the code field — is written and waiting behind it.
  static const phoneAuthEnabled = false;

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
  /// The one account that may read incoming correction requests and note
  /// reports, and mark them handled.
  ///
  /// **An email rather than a uid**, because a uid is not knowable without
  /// signing in as the operator, and this has to be written into
  /// `firestore.rules` where only the token's claims are available. The
  /// address is already in the author line of every commit in a public
  /// repository, so naming it here exposes nothing new — and the rule pairs it
  /// with `email_verified`, because an unverified email in a token is a claim
  /// the account made about itself.
  ///
  /// If this ever changes, `firestore.rules` changes with it. `inbox_test`
  /// fails if the two drift.
  static const operatorEmail = 'davidmalede@gmail.com';

  static const appVersion = '0.9.13+27';
}
