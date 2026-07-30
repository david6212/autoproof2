/// All Hebrew UI strings. Never hardcode Hebrew text in widgets — always
/// reference AppStrings.X.
class AppStrings {
  AppStrings._();

  // App
  static const appName = 'OtoV';
  static const tagline = 'הכוח בידיים שלך';

  // Onboarding
  static const onboard1Title = 'תדעו כיצד המוכר סיווג את עצמו';
  static const onboard1Body =
      'כל מוכר מסווג את עצמו ומוצלב מול מרשם הרכב — פרטי, סוכן או סוחר';
  static const onboard2Title = 'נתונים רשמיים בלחיצה';
  static const onboard2Body = 'ק"מ, טסט, ריקול — ממשרד התחבורה';
  static const onboard3Title = 'דבר ישירות עם המוכר';
  // "מאובטח" reads as end-to-end encryption, which this is not. Security rules
  // do restrict a thread to its two participants, so "פרטי" is accurate.
  static const onboard3Body = 'צ\'אט פרטי וישיר מול המוכר';
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
  static const idOnlyNote = 'מספר הרישוי משמש להשוואה מול מרשם הרכב בלבד 🔒';
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
      'OtoV מספק מידע ממקורות רשמיים ומדיווחי משתמשים. אין לראות במידע זה '
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
