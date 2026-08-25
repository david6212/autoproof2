/// All Hebrew UI strings. Never hardcode Hebrew text in widgets — always
/// reference AppStrings.X.
class AppStrings {
  AppStrings._();

  // App
  static const appName = 'BonnetCheck';
  static const tagline = 'הכוח בידיים שלך';

  /// Canonical public address, used to build shareable listing links.
  /// The legacy autoproof-8d827 host 301-redirects here, so old links keep
  /// working — but anything we hand out ourselves should use this one.
  static const siteUrl = 'https://bonnetcheck.web.app';

  // Onboarding
  // ---- The three slides, rewritten 25/08 ----
  //
  // They opened on how the seller had classified themselves and closed on
  // "chat with the seller", with the registry lookup — the only thing here
  // that no other Israeli app gives away — squeezed into four words between
  // them.
  //
  // The first slide also carried a claim that had just been removed from the
  // car page as untrue: "מוצלב מול מרשם הרכב". `sellerType` is a radio
  // button on the publish form, nothing cross-checks it, and the crowd
  // reports that partly backed it were deleted the same day.
  //
  // The order is the actual ladder now: look up any car, see what does not
  // add up, keep a record of your own. Chat lost its slide — every
  // classifieds app has one, and it was never the reason to install this.
  static const onboard1Title = 'כל רכב בישראל, מול משרד התחבורה';
  static const onboard1Body =
      'מספר רישוי אחד — וק"מ בטסט האחרון, ריקולים פתוחים, שינוי '
      'מבנה וירידה מהכביש. בלי הרשמה.';
  static const onboard2Title = 'מה שלא מסתדר — למעלה';
  static const onboard2Body =
      'אם המודעה מציינת פחות ק"מ ממה שנרשם בטסט האחרון, '
      'תראו את זה ראשון — עם המספר והתאריך.';
  static const onboard3Title = 'לרכב שלכם יש תיק';
  static const onboard3Body =
      'כל טיפול שתתעדו נשמר לצמיתות ואי אפשר לערוך אותו. ביום '
      'שתמכרו, זה מה שיש לכם להראות.';
  static const continueBtn = 'המשך';
  static const skip = 'דלג';

  // Login
  static const sendCode = 'שלח קוד אימות';

  // Verification
  //
  // WORDING RULE: describe the CHECK WE RAN, never label the person. The flow
  // only cross-checks a plate against the vehicle registry — it does not verify
  // anyone's identity or that they own the car (no ID, no ownership document).
  // "מוכר מאומת" claimed far more than that, so every string here states what
  // was actually checked. See BUSINESS_ROADMAP section 10.
  static const verifyOwnerYes = 'כן, אני הבעלים הפרטי';
  static const verifyDealer = 'אני סוחר / סוכן רכב';
  // "נבדק" sounds like an action we performed and vouch for. We only COMPARE
  // the plate against what the registry already publishes, so every string
  // says "הושוו"/"מבוסס על" instead.
  static const verifyingWithGov = 'משווה למידע הזמין במרשם...';
  static const plateNotFound = 'המספר לא נמצא. בדוק את מספר הרישוי.';
  // No emoji in anything a user reads: the app bundles Heebo and Poppins and
  // nothing else, so the web engine has no font to fall back to and draws an
  // empty box. `note_bank_test` scans for this.
  static const idOnlyNote = 'מספר הרישוי משמש להשוואה מול מרשם הרכב בלבד.';
  static const verifiedSuccess = 'ההשוואה הושלמה';
  static const verifiedAsPrivate =
      'נתוני הרכב הושוו למידע הזמין במרשם, והמודעה תסומן לפי הסיווג שבחרת';
  static const continueToListing = 'המשך לפרסום המודעה';

  /// Exactly what the comparison covers — and what it does not.
  static const checkScopeNote =
      'נתוני הרכב הושוו למידע הזמין במרשם הרכב, והמוכר סומן לפי הסיווג שבחר. '
      'לא אימתנו את זהותו ולא את בעלותו על הרכב — בדקו מסמכים מול המוכר.';

  // Home
  static const onlyPrivateSellers = 'מוכרים מסווגים · נתונים ממאגרי משרד התחבורה';

  /// Badge text — describes the data's origin, not an act of ours.
  static const verifiedSellerBadge = 'נתונים ממרשם הרכב';

  // Chat
  static const chatWithVerified = 'מוכר';

  /// Shown on the first screen a user meets, before anything else.
  static const entryDisclaimer =
      'BonnetCheck מספק מידע ממקורות רשמיים ומדיווחי משתמשים. אין לראות במידע זה '
      'אישור לבעלות, לזהות המוכר או לתקינות הרכב.';

  // Common states
  static const loading = 'טוען...';
  static const errorGeneric = 'משהו השתבש. נסה שוב.';
  static const retry = 'נסה שוב';

  // Government data disclaimer
  static const govDisclaimer = 'נתונים רשמיים ממשרד התחבורה · data.gov.il';

  /// Liability notice shown wherever official records and user reports appear
  /// together (BUSINESS_ROADMAP 9.11).
  static const liabilityNotice =
      'המידע באפליקציה משלב נתונים ממקורות רשמיים ודיווחי משתמשים. למרות שנעשה '
      'מאמץ לשמור על דיוקו, ייתכנו טעויות. אין לראות במידע זה תחליף לבדיקה '
      'עצמאית או למידע רשמי.';

  /// Framing required next to any crowd-sourced figure.
  static const communityDataNote =
      'המידע מבוסס על דיווחי משתמשי הקהילה ואינו מידע רשמי.';
}
