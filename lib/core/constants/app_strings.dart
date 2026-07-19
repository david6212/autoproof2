/// All Hebrew UI strings. Never hardcode Hebrew text in widgets — always
/// reference AppStrings.X.
class AppStrings {
  AppStrings._();

  // App
  static const appName = 'AutoProof';
  static const tagline = 'הכוח בידיים שלך';

  // Onboarding
  static const onboard1Title = 'רק בעלים פרטיים. אף סוחר.';
  static const onboard1Body = 'כל מוכר מאומת מול רישוי הרכב';
  static const onboard2Title = 'נתונים רשמיים בלחיצה';
  static const onboard2Body = 'ק"מ, טסט, ריקול — ממשרד התחבורה';
  static const onboard3Title = 'דבר ישירות עם המוכר';
  static const onboard3Body = 'צ\'אט מאובטח, בלי מתווכים';
  static const continueBtn = 'המשך';
  static const skip = 'דלג';

  // Login
  static const sendCode = 'שלח קוד אימות';

  // Verification
  static const verifyOwnerYes = 'כן, אני הבעלים הפרטי';
  static const verifyDealer = 'אני סוחר / סוכן רכב';
  static const verifyingWithGov = 'מאמת מול משרד התחבורה...';
  static const plateNotFound = 'המספר לא נמצא. בדוק את מספר הרישוי.';
  static const idOnlyNote = 'המידע לאימות זהות בלבד 🔒';
  static const verifiedSuccess = 'אומתת בהצלחה';
  static const verifiedAsPrivate = 'את/ה רשום/ה כבעלים פרטי מאומת';
  static const continueToListing = 'המשך לפרסום המודעה';

  // Home
  static const onlyPrivateSellers = 'רק מוכרים פרטיים';
  static const verifiedSellerBadge = 'מוכר מאומת';

  // Chat
  static const chatWithVerified = 'שיחה מול בעלים פרטי מאומת';

  // Common states
  static const loading = 'טוען...';
  static const errorGeneric = 'משהו השתבש. נסה שוב.';
  static const retry = 'נסה שוב';

  // Government data disclaimer
  static const govDisclaimer = 'נתונים רשמיים ממשרד התחבורה · data.gov.il';
}
