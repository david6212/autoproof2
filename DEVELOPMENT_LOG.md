# AutoProof — יומן פיתוח מלא

> שוק מהימן לרכבי יד שנייה בישראל — רק מוכרים פרטיים מאומתים, עם נתונים רשמיים ממשרד התחבורה.
> תמלil מלא של השיחה נשמר אוטומטית ב-`~/.claude/projects/.../*.jsonl`. המסמך הזה הוא הסיכום הקריא.

- **Repo:** github.com/david6212/autoproof2 (פרטי)
- **Firebase:** autoproof-8d827 (תוכנית Spark חינמית)
- **Web חי:** https://autoproof-8d827.web.app
- **מסגרת:** Flutter + Riverpod + go_router + Firebase (Auth/Firestore/Storage/Analytics)

---

## הסיפור בקצרה
התחלנו תקועים ב-**FlutterFlow** (בילדר ויזואלי) עם כרטיס רכב שלא הצליח להתקמפל. עברנו ל-**Flutter אמיתי (קוד) + VS Code**, ומשם בנינו MVP מלא, אבטחנו אותו, מיתגנו, והפכנו אותו למוצר אמון עמוק שנשען על **5 מאגרי משרד התחבורה**.

---

## שלב א' — MVP (19/07/2026)
בנייה מאפס של אפליקציה מלאה, 8 שלבי פיתוח:

| שלב | מה נבנה |
|---|---|
| 1 | תשתית: theme (Heebo, RTL), ניתוב, ~24 מסכים, Firebase |
| 2 | אימות טלפון (OTP) — פתרנו חסם: minSdk 23 + SHA + SMS region |
| 3 | ⭐ נתוני רכב רשמיים מ-data.gov.il |
| 4 | ⭐ אימות מוכר (רק בעלים פרטיים) |
| 5 | ⭐ מסך בית + מודעות + פרסום (3 שלבים + העלאת תמונות) |
| 6 | ⭐ צ'אט בזמן אמת (Firestore) |
| 7 | גילוי והתאמות (Swipe/Match) |
| 8 | פרופיל, אודות, בודקי רכב, מרכז מוכר, התראות |

## שלב ב' — אבטחה ובטא (22-23/07/2026)
- 🔒 **כללי אבטחת Firestore** — ממסד פתוח לגמרי → נעול לפי תפקידים (users/cars/chats/reviews/inspectors/bookings)
- 👤 **גלישת אורח** — "גלוש בלי להתחבר" + חלונות "התחבר כדי ל..." + מסכי הזמנה בשמורים/צ'אטים/פרופיל
- 📋 חיזוק כרטיס נתוני הרכב (באנר מקור רשמי + תוקף רישיון + VIN)
- 📊 **Firebase Analytics** (screen_view + vehicle_lookup + guest_prompt + login_completed + chat_started)
- 🛠️ ניהול מודעה למוכר (סמן כנמכר / הסר)
- 🧹 תוכן אמיתי: 4 מודעות דמו עם פלטות אמיתיות מ-data.gov.il
- 📲 הפצה: PWA branding + APK ב-GitHub Releases (התגלה: repo פרטי → מעבר ל-Google Drive)

## שלב ג' — מיתוג ומסך פתיחה (23-24/07/2026)
- 🎨 לוגו AutoProof (מגן ירוק + רכב + וי) — הוסר רקע, שולב בכל האפליקציה
- 🎬 **מסך פתיחה מונפש** (פורט מ-GSAP): מגן קופץ → רכב נופל → AUTOPROOF מתכנס → וי נמשך
- 🎨 פלטת צבעים אחידה (sage green #558B6E) בכל המסכים
- 🅰️ אייקוני אפליקציה (web + PWA + אנדרואיד) מהלוגו

## שלב ד' — התחברות וחיפוש (24/07/2026)
- 🔐 **3 אפשרויות התחברות**: טלפון (SMS) / **Google (עובד חינם, גם ב-web!)** / Apple (מחכה לחשבון Developer)
- 🔍 חיפוש חי (יצרן/דגם/אזור/פלטה)
- 🎛️ **חלון פילטר מתקדם**: קטלוג יצרנים מקיף (יצרן→דגם), יד, מחיר, שנה, ק"מ, אזור, סוג, הנעה, צבע
- 🖼️ גלריית תמונות אינטראקטיבית במסך הרכב

## שלב ה' — מנוע נתונים ממשלתי (25/07/2026) 💎
הפיכת AutoProof למוצר אמון עמוק — שליפה מ-**5 מאגרי data.gov.il** בכל חיפוש פלטה:

| מאגר | מה מציג |
|---|---|
| רכב פעיל `053cea08` | מפרט מלא (יצרן/דגם/גימור/צבע/דלק/מנוע/זיהום/צמיגים/VIN/טסט/רישיון) |
| היסטוריה `56063a99` | **מד-אוץ רשמי** + **שינוי מבנה** (תאונה) + מקוריות + רישום ראשון |
| ריקול `36bf1404` | **קריאות שירות פתוחות** (באנר אדום) |
| ירד מהכביש `851ecab1` | **גריטה/ביטול סופי** (באנר אדום קריטי) |
| תג נכה `c8b9f9c8` | סטטוס תג חניה לנכה |

בנוסף: פרסום מודעה שומר הנעה/צבע/בעלות מ-gov → הפילטרים עובדים על נתונים אמיתיים; מסך הרכב מציג "מפרט רשמי" ואת מלוא לוח הפרטים.

---

## מגבלות ידועות
- **התחברות טלפון ב-web** חסומה (`BILLING_NOT_ENABLED` — דורש Blaze). Google עובד חינם ב-web. נייטיב עובד חינם.
- **iOS** לא ניתן לבנות ב-Windows (דורש Mac). Apple Sign-In דורש חשבון Apple Developer ($99/שנה).
- **repo פרטי** → קישורי GitHub Releases לא עובדים לאנונימיים (משתמשים ב-Google Drive ל-APK).
- **"אובדן להלכה" (total loss)** לא זמין ציבורית ב-data.gov.il (נתוני ביטוח) — "ירד מהכביש" הוא הקרוב ביותר.
- פילטרים ויזואליים שנותרו ללא נתונים: נפח מנוע, מספר מקומות, סטטוס בדיקת מכון.

## תהליך פריסה (מהמחשב של דוד)
```powershell
# web
flutter build web ; firebase deploy --only hosting
# כללי אבטחה
firebase deploy --only firestore:rules
# APK
flutter build apk --release   # → build/app/outputs/flutter-apk/
```
Firebase Hosting על Spark חוסם העלאת .apk — משתמשים ב-Google Drive/GitHub Releases.

---

## היסטוריית Commits מלאה
```
88885cb 19/07  Initial commit — AutoProof MVP (Phases 1-5)
fc3e9f1 19/07  Phase 6 — real-time chat
b68b6be 19/07  Phase 7 — discovery (swipe) + match
987c577 19/07  Phase 8 — remaining screens
2931fc1 22/07  Secure Firestore with production security rules
d27bf4b 22/07  Add "browse without signing in" guest entry on login
292cd5d 23/07  Guest handling + stronger official vehicle-data card
0e2a3d7 23/07  Match avatar fix + seller listing management
97bfdb7 23/07  Add Firebase Analytics for beta usage insights
e9ce17e 23/07  Brand the web app (PWA identity)
b3c7b97 23/07  Refine app icon: cleaner shield (variant A)
a4dafdd 23/07  Redesign app icon: white "A" monogram on teal gradient
f0af9db 23/07  Integrate real AutoProof logo (shield + car + check)
04769b7 23/07  Bump Kotlin to 2.1.0 for firebase_analytics
1686767 23/07  Switch to new AutoProof logo (gold-trimmed green shield)
6195449 24/07  Use the new logo on About and Login screens
4e611bb 24/07  Add no-cache headers for index.html + service worker
84b49cf 24/07  Luxury splash screen (emerald + gold)
36c7fad 24/07  Remove splash subtitle, keep gold accent
13229ed 24/07  Animated splash: shield + car + drawing checkmark
0a6ddbc 24/07  Fix splash wordmark order (force LTR)
65143b3 24/07  Detailed sedan for the splash car
08b5818 24/07  Use the real car artwork in the splash animation
0b5d644 24/07  Unify app palette with the splash colors
39dca72 24/07  Shrink login logo to a compact emblem
0c3f374 24/07  Reusable splash-style logo; use it on login
a74d75d 24/07  Splash-style logo everywhere (About + app icons)
4d098c9 24/07  Fix AutoproofLogo blowing up in stretch parents
462bbf2 24/07  Add Google + Apple sign-in buttons
23a5f76 24/07  Tidy the login layout (centered, constrained width)
6bfc674 24/07  Polish car detail gallery
d53e1d9 24/07  Make home search + category filters actually work
bd621d0 24/07  Advanced filter sheet (body types + buy filters)
1dc2ab1 24/07  Advanced filter sheet matching the mockup
162ec7d 24/07  Manufacturer/model filter + fix result count
5a67074 25/07  Make fuel/ownership/color filters functional
6e028a1 25/07  Show official specs (fuel/color/owner) on car detail
77f105f 25/07  Show the full Ministry of Transport spec sheet
df020bb 25/07  Connect vehicle-history + open-recall gov datasets
744d4a8 25/07  Connect off-road + disability-tag gov datasets
20fbc87 25/07  Fix lookup for off-road vehicles
```
