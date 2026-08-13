# BonnetCheck — all 23 screens

Companion to `DESIGN_BRIEF.md` (tokens, type, spacing, the brand mark,
components). **Read that one first** — everything here is built from those
tokens and components, and the rules in its §7 apply to every screen below.

Every screen, its structure in order, its states, and its real Hebrew copy —
all read from the shipping code. Hebrew strings are verbatim; keep them unless
you are deliberately proposing new wording, in which case flag it (see §6).

**Everything is RTL.** "Start" means the right edge, "end" means the left.

---

## 1. Navigation map

```
/splash → /onboarding → /login ──┬─→ buyer tabs
                                 └─→ /verify/role → /verify/plate
                                        → /verify/phone → /verify/success
                                        → seller area

Buyer tab bar (floating pill, RTL — first is rightmost):
  /home      בית
  /saved     שמורים
  /fuel      דלק
  /chats     צ'אטים
  /profile   פרופיל

Full-screen, outside the tab bar:
  /car/:id            car detail
  /car/:id/history    official vehicle history
  /compare            comparison table
  /inspectors/:carId  inspection-centre directory (map + list)
  /notifications      /chat/:chatId      /about      /legal      /legal/:docId

Seller area (its own shell):
  /seller  ·  /seller/create  ·  /seller/listing  ·  /seller/removed
```

A user can browse as a **guest**. Guest-facing screens show a sign-in prompt
instead of their content rather than blocking navigation.

---

## 2. Entry

### 2.1 Splash — `/splash`
Animated brand entrance on a plain background. The shield scales in
(ease-out-back) → the car image drops in (bounce-out) → the wordmark rises →
"Bonnet" comes in from the left and the check from the right, meeting → the
check's stroke draws itself on → hold → fade out.

*Design note:* this is the one place the mark is the subject rather than a piece
of type, so the check is enlarged relative to the cap height.

### 2.2 Onboarding — `/onboarding`
Three swipeable slides: an icon, a title, a body line. Page dots, a `דלג` text
button, and a `המשך` primary button that reads as the final CTA on slide 3.

| # | icon | title | body |
|---|---|---|---|
| 1 | shield-check | `תדעו כיצד המוכר סיווג את עצמו` | `כל מוכר מסווג את עצמו ומוצלב מול מרשם הרכב — פרטי, סוכן או סוחר` |
| 2 | insights | `נתונים רשמיים בלחיצה` | `ק"מ, טסט, ריקול — ממשרד התחבורה` |
| 3 | chat bubble | `דבר ישירות עם המוכר` | `צ'אט פרטי וישיר מול המוכר` |

### 2.3 Login — `/login`
Centred, max width 380, **no app bar** (it repeated the name above the logo).

Order: brand logo → tagline `הכוח בידיים שלך` → phone field `מספר טלפון` →
primary `שלח קוד אימות` → divider `או` → `המשך עם Google` → `המשך עם Apple` →
`גלוש בלי להתחבר ←` → consent note.

Code state replaces the phone field: `הזן את הקוד שקיבלת`,
`שלחנו קוד בן 6 ספרות אל +972…`, `אמת קוד`, `שנה מספר טלפון`.

Consent note: `בהתחברות או בגלישה אתם מאשרים את` + link
`תנאי השימוש ומדיניות הפרטיות`.

Error banner copy (each is a distinct state, not one generic message):
`ההתחברות נכשלה. נסו שוב.` · `שיטת ההתחברות הזו עדיין לא זמינה. נסו עם Google
או עם מספר טלפון.` · `קיים כבר חשבון עם האימייל הזה. התחברו בשיטה שבה נרשמתם.` ·
`אין חיבור לאינטרנט. בדקו ונסו שוב.` · `יותר מדי ניסיונות. נסו שוב מאוחר יותר.`

*Two things to preserve:* cancelling a provider popup is **not** an error and
shows nothing. The Apple button is honest that the method is unavailable rather
than pretending it failed.

---

## 3. Buyer

### 3.1 Home — `/home` ★ most-used screen
Order: header → filter pills → list.

- **Header** — brand logo + wordmark; a notification bell (`התראות`) with an
  unread dot; a link to `אודות BonnetCheck`. Subtitle line:
  `מוכרים מסווגים · נתונים ממאגרי משרד התחבורה`.
- **Search field** — `חיפוש לפי יצרן, דגם, אזור או מספר רכב`, with a clear
  button (`נקה חיפוש`) and a filter button at the end carrying a count badge:
  `סינון` / `סינון · N מסננים פעילים`.
- **Filter pills** — horizontal, single select:
  `הכל · משפחתי · קרוסאובר · היברידי · חשמלי · ספורט`.
- **Result count** — `N רכבים בקרבתך`.
- **List** — car cards; one per row, **two per row past 620px**.
- **Loading** — card skeletons, never a spinner.
- **Empty** — `לא נמצאו רכבים תואמים` with `נקה חיפוש וסינון`; or
  `אין רכבים להצגה כרגע` when nothing is filtered.

### 3.2 Filter sheet (from the search bar)
A bottom sheet: dependent יצרן → דגם dropdowns, hand pills, price / year / km
sliders, area, fuel, colour dots, ownership, engine capacity, seats, drivetrain.
A badge on the trigger shows how many groups are active.

*Note:* two filters were deliberately **removed** rather than built — inspection
status (no data source exists) and the disability tag (health-adjacent personal
data). Do not reintroduce them.

### 3.3 Car detail — `/car/:id` ★ the densest screen
A scrolling stack, in this exact order:

1. **Photo gallery** — height `width × 0.72`, clamped 240–360 and never more
   than half the viewport. One position indicator only: dots up to 8 photos, a
   numeric chip beyond. Tapping opens a full-screen pinch/double-tap viewer.
2. **Title, price, stats row** — `92,000 ק"מ · יד 2 · 2019 · תל אביב`.
3. **Official red flags** — open recalls, off-road/deregistered, structural
   change. A red banner, only when there is something to say.
4. **Official specs** — chip row headed `מפרט רשמי · משרד התחבורה`.
5. **Value insights** — `תובנות שווי`: `ק"מ ממוצע לשנה` tagged
   `מתחת לממוצע` / `ממוצע` / `מעל הממוצע` (bands at 12k and 18k), and
   `סוג בעלות` tagged `פרטי ✓` or `שימוש מסחרי`.
6. **Seller's own words** — `מהמוכר`, as a quote card. Only if written.
7. **Plate history** — `בדיקת קילומטראז' והיסטוריה`: past listings of this
   plate plus the official last-test reading. Flags an **odometer rollback** in
   red. Renders nothing when there is no history.
8. **Seller card** — the seller-type badge and what it means:
   `הרכב רשום כבעלות פרטית במרשם` / `סוכן — מוכר בשם בעל הרכב` /
   `סוחר / מגרש רכב`.
9. **Buyer encounters** — what buyers who actually met the seller reported.
   Warns when the crowd contradicts the declared type.
10. **History button** — `היסטוריית רכב רשמית`.
11. **Buyer journey** — a 4-stage stepper: official-data check ✓ → physical
    inspection → pre-decision deep check → purchase + insurance. Each stage has
    one advance button; progress is saved per buyer.
12. **Visitor notes** — crowd-sourced, factual, visible to everyone including
    the seller, each with a report button.
13. **Liability notice**.
14. **Sticky action bar** — `שלח הודעה` (primary), save, share, report
    (`דווח על המודעה`), and a wrench to the inspection-centre directory.

*The ordering is the argument the screen makes:* what the registry says comes
before what people say, and the liability notice closes it.

### 3.4 Comparison — `/compare`
Covered in `DESIGN_BRIEF.md` §6. Two or three cars, pinned header, three
sections (`המודעה` / `מפרט הדגם` / `רשומות משרד התחבורה`), zebra rows, warning
outranks advantage, and the closing note:
`הסימון הירוק מציין את הערך העדיף בשורה אחת בלבד. האפליקציה לא מדרגת רכבים ולא
ממליצה על אחד מהם — שקלול בין מחיר להיסטוריה הוא שיקול שלכם.`
Empty state: `צריך לפחות שני רכבים להשוואה`.

### 3.5 Saved — `/saved`
The saved list, plus a **selection mode** for comparison: an app-bar action
toggles between `השוואה` and `ביטול`, cards gain a tick circle and a teal
border, and a bottom bar reads `נבחר N מתוך 2 לפחות` → `נבחרו N רכבים` with a
`השווה` button. Over the limit:
`אפשר להשוות עד 3 רכבים — הסירו אחד כדי להוסיף אחר.`

Guest: `שמור רכבים שאהבת` / `התחבר כדי לשמור רכבים ולחזור אליהם בקלות.`
Empty: `עדיין לא שמרת רכבים` + `עבור לרכבים`.

### 3.6 Fuel stations — `/fuel`
Map first, list toggle in the app bar. 1,255 official stations.

- **Reference price card** — `סולר לתחבורה — X ₪ לליטר`,
  `בשער בית הזיקוק (חודש)`, and the disclaimer that must stay:
  `מחיר סיטונאי לפני בלו ומע"מ, לא המחיר במשאבה. מחירי סולר בפועל אינם מפוקחים
  ואינם מתפרסמים לפי תחנה.`
- **Search** — `חיפוש לפי עיר, שם תחנה או חברה…`
- **Sort chips** — `הקרובות אליי` · `המחיר שדווח`, subtitled
  `לפי המחיר הזול ביותר שדיווחו נהגים ב-14 הימים האחרונים`.
- **Station card** — name, company, address, distance, `ניווט`,
  `דווח מחיר` / `עדכן`, and an honest empty state:
  `אין דיווח על מחיר סולר בתחנה הזו` · `הדיווח האחרון כאן ישן מדי (…)` ·
  `מעט דיווחים — ייתכן שאינו מייצג`.
- Footer: `N תחנות · מקור: משרד האנרגיה`.

*Rule:* the sort is worded "the cheapest **reported by drivers**", never "the
cheapest diesel". A station with no report sinks to the bottom — unreported is
not expensive.

### 3.7 Inspection centres — `/inspectors/:carId`
134 licensed pre-purchase inspection centres, official data. Opens on a
clustered map; toggle to a list. Search `חיפוש לפי עיר או שם מכון…`. Tapping a
pin raises a card with `התקשר` and `ניווט`. City-level pins say so:
`הסיכה במרכז העיר — התקשרו לכתובת המדויקת`. Hints:
`הקישו על עיר או התקרבו כדי לראות את המכונים` ·
`אפשרו גישה למיקום כדי לראות את המכון הקרוב אליכם`.
Footer: `N מכונים מורשים · מקור: משרד התחבורה`.

### 3.8 Vehicle history — `/car/:id/history`
A plate field (`מספר רישוי`), a `בדוק` button, and the full official data card.
Idle hint: `הזן מספר רישוי לקבלת נתונים רשמיים`.

### 3.9 Notifications — `/notifications`
`ההתראות שלך` — message tiles with relative times (`עכשיו`, `לפני N דק'`,
`לפני N שעות`, `לפני N ימים`).
Empty: `אין התראות חדשות` / `כשמוכר ישיב להודעה שלך, היא תופיע כאן.`
Guest: `התחבר כדי לקבל עדכון כשמוכר משיב לך.`

---

## 4. Selling

### 4.1 Verification — a 4-step flow with a step-progress bar

**`/verify/role` — `מי אתה?`** Three options, presented as equals:
`כן, אני הבעלים הפרטי` · `אני סוכן` (`מוכר רכב בשם מישהו אחר`) ·
`אני סוחר / מגרש` (`עסק למכירת רכבים`). Note underneath:
`הסיווג שתבחר יוצג בבירור במודעה, כדי שהקונה יידע כיצד סיווגת את עצמך.`

**`/verify/plate` — `אימות בעלות`** `הזן את מספר הרישוי של הרכב שברשותך` →
`אמת מול משרד התחבורה` → a confirmation card for the car found, plus a full-name
field. Privacy line: `מספר הרישוי משמש להשוואה מול מרשם הרכב בלבד 🔒`.
Not found: `המספר לא נמצא. בדוק את מספר הרישוי.` + `הזן מספר אחר`.

**`/verify/phone` — `אימות מספר טלפון`** Required before publishing.
`כדי לפרסם מודעה צריך מספר טלפון מאומת` and the reason, which should stay:
`המספר משמש לאימות בלבד ולא יוצג במודעה. הוא מקשה על פתיחת חשבונות מזויפים ומגן
גם עליך וגם על הקונים.`

**`/verify/success`** `ההשוואה הושלמה` + a preview of the car +
`המשך לפרסום המודעה`.

> **Wording rule, load-bearing.** This flow compares a plate against the public
> registry. It does **not** verify anyone's identity or ownership — no ID, no
> documents. So the copy describes *the check that ran*, never labels the
> person: `הושוו` and `מבוסס על`, never `נבדק`; `נתונים ממרשם הרכב`, never
> `מוכר מאומת`. The full scope line is:
> `נתוני הרכב הושוו למידע הזמין במרשם הרכב, והמוכר סומן לפי הסיווג שבחר. לא
> אימתנו את זהותו ולא את בעלותו על הרכב — בדקו מסמכים מול המוכר.`
> Any redesign that makes this feel like a verified-seller badge is wrong, however
> much better it looks.

### 4.2 Seller home — `/seller`
`מרכז המוכר`, `שלום, <name>`. Either the active listing card or an empty state
(`אין לך מודעה פעילה` / `פרסם את הרכב שלך ותתחיל לקבל פניות` / `פרסם מודעה`),
then `טיפים למכירה מהירה`:
`העלה לפחות 6 תמונות באור יום — מודעות עם תמונות נצפות פי 3.` ·
`הגב להודעות תוך שעה כדי לא לאבד קונים מתעניינים.`

### 4.3 Create listing — `/seller/create` — three steps + a success screen
Step bar at the top, a sticky bottom bar with the action.

1. **`הוסף תמונות של הרכב`** — `עד 12 תמונות. הראשונה תשמש כתמונת השער.` An add
   tile plus thumbnails; the first is marked `שער`.
2. **Details** — `מחיר (₪)`, `קילומטראז'`, `אזור` (a picker of the ten main
   cities plus `אחר`), `כמה מילים על הרכב` (placeholder: `למשל: רכב שמור, טופל
   תמיד במוסך מורשה, ללא תאונות, צמיגים חדשים…`), `סיבת המכירה` (`למשל: עוברים
   לרכב גדול יותר`). Above them, a read-only card of the verified car:
   `<year> · <fuel> · אומת מול משרד התחבורה`.
3. **`סקירה ואישור`** — a summary (רכב / שנה / מחיר / ק"מ / תמונות / על הרכב),
   the note `תג "נתונים ממרשם הרכב" והסיווג שבחרת יוצגו במודעה`, and
   `פרסם מודעה`.

**Odometer confirm dialog** — fires when the entered km is below the last
official test reading: `לבדוק את הקילומטראז'` · `ייתכן שזו טעות הקלדה. אם המספר
נכון — למשל לאחר החלפת מד-אוץ — אפשר להמשיך, וההפרש יוצג לקונים לצד הנתון
הרשמי.` · `חזרה לתיקון` / `המספר נכון, פרסם`. **A warning, not a block** — an
odometer can legitimately be replaced and the registry reading can be stale.

**Success** — `המודעה פורסמה!` / `הרכב שלך זמין כעת לקונים ב-BonnetCheck`, three
counters (`צפיות` / `שמירות` / `הודעות`), `למודעה שלי`.

**Gate** — unverified sellers get `יש להשלים אימות מוכר לפני פרסום מודעה` +
`לאימות מוכר`.

### 4.4 My listing — `/seller/listing`
`המודעה שלי` — three stats (`צפיות` / `מתעניינים` / `ימים פעילה`), an
interested-buyers section (`מי מתעניין ברכב שלך`, empty: `כאן יופיעו קונים
שמתעניינים ברכב שלך`), `שתף את המודעה`, `הצ'אטים שלי`, and two destructive
actions, each behind a confirm dialog:
`לסמן כנמכר?` → `המודעה תוסר מרשימת הרכבים הפעילים. אפשר לפרסם רכב חדש לאחר מכן.`
→ `כן, נמכר` → toast `מזל טוב! המודעה סומנה כנמכרה`.
`להסיר את המודעה?` → `המודעה תוסר מהמערכת. פעולה זו אינה הפיכה.` → `הסר`.

### 4.5 Listing removed — `/seller/removed`
`המודעה הוסרה` / `בעקבות דיווחים חוזרים על אי-התאמה`, three explanation lines,
and `להגיש ערעור`. Firm, not punitive — the tone should leave an honest seller
feeling they have a route back.

---

## 5. Shared

### 5.1 Chats — `/chats` and `/chat/:chatId`
List: tiles with the other party (`קונה מתעניין` / `מוכר`), last message,
time, unread badge. Empty `אין עדיין שיחות`. Guest: `שוחח עם המוכרים` /
`התחבר כדי לפתוח שיחות עם בעלי הרכבים.`

Thread: a header with the car and the other party, message bubbles, an input bar
(`הקלד הודעה...`), and an info banner. Empty: `שלח הודעה ראשונה למוכר`.

### 5.2 Profile — `/profile`
Avatar, name (`משתמש BonnetCheck`), and the `נתונים ממרשם הרכב` badge with
`השוואה למרשם: הושלמה ✓` when done. Menu rows: `המודעות שלי` · `רכבים שמורים` ·
`השוואה למרשם הרכב` · `אודות BonnetCheck` · `תנאי שימוש ופרטיות` ·
`בקשת מחיקת המידע שלי` · `התנתקות`.

**Dark mode is a switch, not a picker**: `מצב כהה` reading `דולק` / `כבוי` /
`לפי הגדרות המכשיר`, with `חזרה להגדרות המכשיר` once the user has chosen.

Deletion dialog: `בקשת מחיקת מידע` · `נטפל בבקשה ונמחק את המידע האישי שלך
מהמערכת. מודעות ודיווחים שפרסמת ייבדקו בנפרד. נחזור אליך באמצעי הקשר הרשום
בחשבון.` · `שלח בקשה`.

### 5.3 About — `/about`
The brand logo and the four trust layers as cards:
`נתונים ממרשם הרכב` · `נתונים רשמיים` · `מכוני בדיקה מורשים` · `צ'אט פרטי`,
each with the plain-language explanation of what it does — including the
sentence that limits it: `איננו מאמתים זהות או בעלות.` Links to
`תנאי שימוש, פרטיות ונהלים`.

### 5.4 Legal — `/legal`, `/legal/:docId`
`מידע משפטי` — an index of the documents plus a last-updated line.
Currently a pending state, which is accurate and should be designed as a real
state rather than hidden: `המסמכים המשפטיים בהכנה` / `תנאי השימוש, מדיניות
הפרטיות ושאר המסמכים ייפורסמו כאן עם השלמת פרטי המפעיל. עד אז, ההבהרות לגבי מה
שהשירות בודק ומה לא מופיעות במסך "אודות".` → `למסך אודות`.

---

## 6. Cross-cutting

**Every list screen needs four states** — loading (skeletons, not spinners),
loaded, empty (with a way out), error (`משהו השתבש. נסה שוב.` + `נסה שוב`).

**Guest state** — icon, title, one line, sign-in action. Used on saved, chats,
notifications, profile.

**Disclaimers that must appear, not be tidied away:**
- Entry: `BonnetCheck מספק מידע ממקורות רשמיים ומדיווחי משתמשים. אין לראות
  במידע זה אישור לבעלות, לזהות המוכר או לתקינות הרכב.`
- Beside official data: `נתונים רשמיים ממשרד התחבורה · data.gov.il`
- Beside any crowd figure: `המידע מבוסס על דיווחי משתמשי הקהילה ואינו מידע רשמי.`
- Wherever both appear together: the full liability notice.

**Copy rules for anything you rewrite:**
1. Describe the check that ran, never label the person.
2. `צ'אט פרטי`, never `מאובטח` — it is not end-to-end encrypted.
3. Never promise a car is sound, only what the records say.
4. Do not rank seller types.
5. Missing data reads `לא דווח`, never `0` and never blank.
6. **No real Israeli plate in any mockup.**

---

## 7. What I would like back

Screens as cards, light and dark, RTL, at phone width, using the components and
tokens from `DESIGN_BRIEF.md`. Priority order — these are the screens users
actually spend time in:

1. **Home** · 2. **Car detail** · 3. **Comparison** · 4. **Saved** ·
5. **Create listing** (all three steps) · 6. **Login** · 7. **Profile** ·
8. Fuel stations · 9. Inspection centres · 10. the rest.

Also worth designing explicitly, because they are where the product is usually
weakest: the empty, loading and error states listed in §6, and the guest state.

Where a screen could be better, propose the alternative and say what it fixes.
The layout is measured, not sacred. The rules in §6 and in `DESIGN_BRIEF.md` §7
are the part that is fixed — they each come from a promise the product made or a
legal risk already mapped.
