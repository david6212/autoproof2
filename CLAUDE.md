> # ⚠️ READ THIS FIRST — THIS FILE IS THE ORIGINAL BUILD SPEC, NOT THE CURRENT STATE
>
> Everything below describes the app as it was *planned* in July 2026. The app
> was built, and reality moved. **Several instructions below are now actively
> wrong and will break things if followed.** Corrections, in order of danger:
>
> | This file says | Reality |
> |---|---|
> | Firebase project `bonnetcheck-app` | **`autoproof-8d827`.** A project id cannot be renamed. |
> | Cloud Functions (Node 20) | **None.** We are on the free Spark plan — no Functions, no FCM push, no scheduled jobs. Everything is client-side. |
> | `AppColors.x` | **`context.colors.x`.** `AppColors` was deleted; a `static const` cannot follow the light/dark theme. |
> | Firebase Storage "already enabled" | **Not provisioned at all.** `firebase deploy --only storage` fails. Photo, receipt and document upload cannot work until somebody clicks Get Started in the console. |
> | `flutter build web` then deploy | **Deploys nothing useful.** Hosting serves `build/hosting`, assembled by `tool/build_site.sh`. The app lives at `/app/`, the landing page at `/`. |
> | Phases 1–18 | All shipped, plus a vehicle passport the spec never had. See `OTOV_SPEC_REVIEW.md`. |
>
> **Current state:** 272 tests passing, analyzer clean, live at
> https://bonnetcheck.web.app (app at `/app/`). The bottom tabs are
> בית · הרכב שלי · דלק · צ'אטים · פרופיל.
>
> **What is still open:** the five legal documents (blocked on the operating
> entity, a contact email and an address — do not invent them), Firebase
> Storage, and `applicationId` still being `il.autoproof.autoproof`, which must
> be sorted before a Play Store launch or Google Sign-In breaks.
>
> Keep this file for the design intent and the wording rules, which still hold.
> Do not follow its setup instructions.

---

# BonnetCheck — Flutter App
## Claude Code Build Instructions
> **Read this entire file before writing a single line of code.**
> Build one phase at a time. Confirm each phase works before moving to the next.
> Always write complete files — never use `// TODO` or `// implement this`.
---
## WHAT YOU ARE BUILDING
**App name:** BonnetCheck  
**Tagline:** הכוח בידיים שלך / The Power is Yours  
**Platform:** Flutter 3.x — iOS + Android from one codebase  
**Backend:** Firebase (Auth, Firestore, Storage, FCM, Functions)  
**External API:** data.gov.il — Israeli Ministry of Transport (free, public)  
**Language:** Hebrew — full RTL layout throughout  
**Mission:** Make buying a used car in Israel fast, safe, and transparent.  
BonnetCheck verifies every seller against the government vehicle registry,
shows official car data inside the app, connects buyers with independent
inspectors, and enables direct real-time chat — all in one place.
---
## BRAND & COLORS
```dart
// lib/core/constants/app_colors.dart
import 'package:flutter/material.dart';
class AppColors {
  // Primary
  static const teal        = Color(0xFF0F6E56);
  static const tealDark    = Color(0xFF0B3D33);
  static const tealLight   = Color(0xFFE1F5EE);
  static const tealText    = Color(0xFF04342C);
  static const tealText2   = Color(0xFF085041);
  // Backgrounds
  static const background  = Color(0xFFF4F3EE);
  static const white       = Color(0xFFFFFFFF);
  static const cardBorder  = Color(0xFFE2E0D8);
  // Text
  static const textPrimary = Color(0xFF15191D);
  static const textMuted   = Color(0xFF5F5E5A);
  static const textSubtle  = Color(0xFF9C9B96);
  // Semantic
  static const errorRed    = Color(0xFFE5604D);
  static const errorBg     = Color(0xFFFCEBEB);
  static const warnBg      = Color(0xFFFBE7D4);
  static const warnText    = Color(0xFF7A3E0A);
  static const starColor   = Color(0xFFBA7517);
  static const mintAccent  = Color(0xFF5DCAA5);
}
```
**Font:** Heebo (Hebrew-friendly Google Font)  
**Direction:** RTL — wrap `MaterialApp` with `Directionality(textDirection: TextDirection.rtl)`  
**Design feel:** Clean, minimal, like a premium fintech app — not a classifieds board.
---
## TECH STACK
### pubspec.yaml dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  # Firebase
  firebase_core: ^3.0.0
  firebase_auth: ^5.0.0
  cloud_firestore: ^5.0.0
  firebase_storage: ^12.0.0
  firebase_messaging: ^15.0.0
  # State Management
  flutter_riverpod: ^2.5.0
  # Navigation
  go_router: ^14.0.0
  # HTTP — data.gov.il API
  dio: ^5.4.0
  # UI helpers
  cached_network_image: ^3.3.0
  image_picker: ^1.1.0
  image_cropper: ^5.0.0
  # Utils
  intl: ^0.19.0
  flutter_secure_storage: ^9.0.0
  google_fonts: ^6.2.0
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```
---
## PROJECT STRUCTURE
Create this exact folder structure:
```
bonnetcheck/
├── CLAUDE.md                          ← this file
├── pubspec.yaml
├── firebase.json
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── app.dart                   # MaterialApp + theme + RTL
│   │   ├── router.dart                # go_router — all 24 routes
│   │   └── theme.dart                 # ThemeData with BonnetCheck colors
│   │
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_colors.dart        # all color constants (see above)
│   │   │   ├── app_strings.dart       # all Hebrew UI strings
│   │   │   └── api_constants.dart     # data.gov.il endpoint + resource_id
│   │   └── utils/
│   │       ├── date_formatter.dart    # YYYYMMDD → DD/MM/YYYY
│   │       ├── plate_formatter.dart   # "1234567" ↔ "123-456-7"
│   │       └── validators.dart        # plate validation, km validation
│   │
│   ├── data/
│   │   ├── models/
│   │   │   ├── user_model.dart
│   │   │   ├── car_model.dart
│   │   │   ├── gov_data_model.dart    # data.gov.il response shape
│   │   │   ├── inspector_model.dart
│   │   │   ├── booking_model.dart
│   │   │   ├── review_model.dart
│   │   │   └── message_model.dart
│   │   ├── repositories/
│   │   │   ├── auth_repository.dart
│   │   │   ├── car_repository.dart
│   │   │   ├── gov_api_repository.dart
│   │   │   ├── inspector_repository.dart
│   │   │   └── chat_repository.dart
│   │   └── sources/
│   │       └── remote/
│   │           ├── firebase_service.dart
│   │           └── gov_api_service.dart
│   │
│   ├── domain/
│   │   └── usecases/
│   │       ├── verify_plate_usecase.dart
│   │       ├── validate_km_usecase.dart
│   │       ├── create_listing_usecase.dart
│   │       └── send_message_usecase.dart
│   │
│   └── presentation/
│       ├── screens/
│       │   ├── auth/
│       │   │   ├── splash_screen.dart
│       │   │   ├── onboarding_screen.dart
│       │   │   └── login_screen.dart
│       │   ├── verify/
│       │   │   ├── verify_role_screen.dart
│       │   │   ├── verify_plate_screen.dart
│       │   │   └── verify_success_screen.dart
│       │   ├── buyer/
│       │   │   ├── home_screen.dart
│       │   │   ├── car_detail_screen.dart
│       │   │   ├── vehicle_history_screen.dart
│       │   │   ├── inspectors_screen.dart
│       │   │   ├── book_inspection_screen.dart
│       │   │   ├── swipe_prefs_screen.dart
│       │   │   ├── swipe_screen.dart
│       │   │   ├── match_screen.dart
│       │   │   ├── saved_screen.dart
│       │   │   ├── notifications_screen.dart
│       │   │   └── quick_review_screen.dart
│       │   ├── seller/
│       │   │   ├── seller_home_screen.dart
│       │   │   ├── add_car_step1_screen.dart
│       │   │   ├── add_car_step2_screen.dart
│       │   │   ├── add_car_step3_screen.dart
│       │   │   ├── my_listing_screen.dart
│       │   │   └── listing_removed_screen.dart
│       │   └── shared/
│       │       ├── chat_list_screen.dart
│       │       ├── chat_screen.dart
│       │       ├── profile_screen.dart
│       │       └── about_screen.dart
│       │
│       ├── widgets/
│       │   ├── car_card_widget.dart
│       │   ├── verified_badge_widget.dart
│       │   ├── gov_data_card_widget.dart
│       │   ├── chat_bubble_widget.dart
│       │   ├── inspector_card_widget.dart
│       │   ├── primary_button_widget.dart
│       │   ├── loading_widget.dart
│       │   └── error_widget.dart
│       │
│       └── providers/
│           ├── auth_provider.dart
│           ├── cars_provider.dart
│           ├── gov_api_provider.dart
│           ├── chat_provider.dart
│           └── inspector_provider.dart
│
├── functions/
│   ├── package.json
│   └── index.js                       # Cloud Functions
└── test/
    ├── unit/
    └── widget/
```
---
## FIREBASE STRUCTURE
**Project ID:** `bonnetcheck-app`  
**Enable these services:**
- Authentication: Phone OTP + Google + Apple
- Firestore: start in test mode
- Storage: start in test mode
- FCM: push notifications
- Cloud Functions: Node.js 20
### Firestore Collections
```
users/{uid}
  name: string
  phone: string
  role: 'buyer' | 'seller' | 'inspector'
  verified: boolean          ← true after plate cross-check passes
  rating: number
  createdAt: timestamp
cars/{carId}
  plate: string              ← license plate, no dashes
  make: string
  model: string
  year: int
  price: double
  km: int
  hand: int                  ← number of previous owners
  area: string
  sellerId: string
  status: 'active' | 'removed' | 'sold'
  govData: map               ← full GovData object
  photos: string[]           ← Storage download URLs
  reasonForSelling: string
  createdAt: timestamp
inspectors/{uid}
  name: string
  certLevel: string
  rating: double
  reviewCount: int
  price: int
  available: boolean
  location: GeoPoint
bookings/{bookingId}
  carId: string
  inspectorId: string
  buyerId: string
  slot: timestamp
  topics: string[]
  status: 'pending' | 'confirmed' | 'completed'
  amount: int
  paidAt: timestamp
reviews/{reviewId}
  carId: string
  reviewerId: string
  anonymous: boolean
  stars: int
  reason: string
  text: string
  createdAt: timestamp
  ← IMPORTANT: no sellerId field. Seller cannot see this.
matches/{matchId}
  carId: string
  buyerId: string
  sellerId: string
  status: 'pending' | 'matched'
  chatId: string
  createdAt: timestamp
messages/{msgId}
  chatId: string
  senderId: string
  text: string
  createdAt: timestamp
reports/{reportId}
  carId: string
  reporterId: string
  reason: string
  createdAt: timestamp
```
### Security Rules (basic)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write only their own document
    match /users/{uid} {
      allow read, write: if request.auth.uid == uid;
    }
    // Only verified sellers can create car listings
    match /cars/{carId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.verified == true;
      allow update, delete: if request.auth.uid == resource.data.sellerId;
    }
    // Messages: only participants can read
    match /messages/{msgId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
    }
    // Reports: any authenticated user can write
    match /reports/{reportId} {
      allow create: if request.auth != null;
    }
  }
}
```
---
## GOVERNMENT API — data.gov.il
```dart
// lib/core/constants/api_constants.dart
class ApiConstants {
  static const govApiBase =
    'https://data.gov.il/api/3/action/datastore_search';
  static const vehicleResourceId =
    '053cea08-09bc-40ec-8f7a-156f0677aff3';
}
// Usage:
// GET https://data.gov.il/api/3/action/datastore_search
//   ?resource_id=053cea08-09bc-40ec-8f7a-156f0677aff3
//   &q=1234567          ← plate number WITHOUT dashes
//   &limit=1
```
### Response fields to parse
| Field | Hebrew | Usage |
|---|---|---|
| `tozeret_nm` | יצרן | Car manufacturer |
| `kinuy_mishari` | שם מסחרי | Commercial name |
| `degem_nm` | דגם | Model |
| `shnat_yitzur` | שנת ייצור | Year |
| `tzeva_rechev` | צבע | Color |
| `sug_delek_nm` | סוג דלק | Fuel: 1=בנזין 2=דיזל 4=חשמלי 5=היברידי |
| `baalut` | בעלים | Number of owners (יד) |
| `mivchan_acharon_dt` | טסט אחרון | YYYYMMDD → DD/MM/YYYY |
| `km_acharon_tirut` | ק"מ בטסט | KM at last test — **use for seller KM validation** |
| `tokef_dt` | תוקף רישיון | License expiry YYYYMMDD |
| `ramat_eivzur_betihuty` | אבזור בטיחות | Safety rating string |
| `misgeret_yeud_1` | ליסינג | '1' = was leased → show RED |
| `misgeret_yeud_2` | השכרה | '1' = was rental → show RED |
| `misgeret_yeud_3` | מונית | '1' = was taxi → show RED |
| `misgeret_yeud_4` | הוראה | '1' = driving lessons → show RED |
**If all misgeret_yeud fields are '0' or null → show GREEN "פרטי"**
```dart
// lib/data/models/gov_data_model.dart
class GovData {
  final String make;
  final String commercialName;
  final String model;
  final int year;
  final String color;
  final String fuelType;      // mapped from sug_delek_nm
  final int owners;           // baalut
  final DateTime? lastTestDate;
  final int? lastTestKm;      // ← KEY FIELD for seller verification
  final DateTime? licenseExpiry;
  final String safetyRating;
  final bool wasLease;
  final bool wasRental;
  final bool wasTaxi;
  final bool wasDrivingLesson;
  bool get isCommercialUse =>
    wasLease || wasRental || wasTaxi || wasDrivingLesson;
  // Fuel type map
  static String mapFuelType(String? code) {
    const map = {
      '1': 'בנזין', '2': 'דיזל', '3': 'גז',
      '4': 'חשמלי', '5': 'היברידי', '6': 'היברידי תקע',
    };
    return map[code] ?? code ?? 'לא ידוע';
  }
}
```
---
## ALL 24 SCREENS
### א — ONBOARDING
**01 · SplashScreen**
- Full screen gradient: #0B3D33 → #0F6E56
- Center: BonnetCheck shield logo + name
- Tagline: "הכוח בידיים שלך"
- Logic: if `FirebaseAuth.currentUser != null` → go `/home`, else → go `/onboarding`
- Duration: 1500ms
**02 · OnboardingScreen**
- 3 slides with PageView
- Slide 1: shield icon | "רק בעלים פרטיים. אף סוחר." | "כל מוכר מאומת מול רישוי הרכב"
- Slide 2: chart icon | "נתונים רשמיים בלחיצה" | "ק"מ, טסט, ריקול — ממשרד התחבורה"
- Slide 3: chat icon | "דבר ישירות עם המוכר" | "צ'אט מאובטח, בלי מתווכים"
- Dots indicator + "המשך" button + "דלג" ghost
**03 · LoginScreen**
- Phone field with +972 prefix
- "שלח קוד אימות" → Firebase Phone Auth
- OTP screen: 6-digit boxes + 60s resend timer
- Also: Google Sign In + Apple Sign In buttons
---
### ב — SELLER VERIFICATION
**04 · VerifyRoleScreen**
- Progress: step 1/3
- Option A ✓ selected teal: "כן, אני הבעלים הפרטי"
- Option B 40% opacity disabled: "אני סוחר / סוכן רכב"
- Dealers are completely blocked. Show explanation text.
- → Continue button
**05 · VerifyPlateScreen**
- Progress: step 2/3
- Plate input (LTR, numbers only, no dashes)
- On submit: call data.gov.il API
- Loading state: spinner + "מאמת מול משרד התחבורה..."
- Success: green card showing make/model/year + registered owner name
- Name field: user types their full name
- Validation: must match registered owner from API
- Error state: "המספר לא נמצא. בדוק את מספר הרישוי."
- Lock note: "המידע לאימות זהות בלבד 🔒"
**06 · VerifySuccessScreen**
- Progress: step 3/3
- Large shield checkmark (teal, #E1F5EE background circle)
- "אומתת בהצלחה"
- "את/ה רשום/ה כבעלים פרטי מאומת"
- Auto-filled car preview card
- Write `verified: true` to Firestore users/{uid}
- → "המשך לפרסום המודעה"
---
### ג — BUYER (14 screens)
**07 · HomeScreen**
- Header: location + "רק מוכרים פרטיים" + shield icon + bell icon (→ NotificationsScreen)
- Search bar
- Filter pills: [הכל][משפחתי][קרוסאובר][היברידי][חשמלי][ספורט]
- Counter: "X רכבים בקרבתך"
- Vertical list of CarCardWidgets (Firestore stream)
- Bottom TabBar: בית | שמורים | גילוי | צ'אטים | פרופיל
**CarCardWidget** displays:
- Photo (160px, cached_network_image)
- "מוכר מאומת ✓" badge top-right
- Review count bottom-left (if any)
- Make/model/year | price
- km · hand · area
**08 · CarDetailScreen**
- Hero photo gallery (horizontal PageView, full width)
- Back button (over photo, top-left)
- Gradient overlay: car name + price at bottom of photo
- Stats row: km | engine | hand
- Seller card (tappable → ChatScreen):
  avatar + name + verified shield + "בעלים פרטי מאומת · לא סוחר"
- Vehicle History button → VehicleHistoryScreen
- Section "חוות דעת מבדיקה אמיתית": review cards
  - Each: avatar + name + stars + text + "בדיקה פיזית מאומתת ✓" badge
  - Reviews are anonymous if `anonymous: true`
- Bottom action bar: [💬 שלח הודעה] [🔧 inspector] [❤️ save]
**09 · VehicleHistoryScreen**
- Plate input (auto-filled from current car)
- "בדוק" button → calls data.gov.il
- Loading / Error / Success states
- Result: dark header card (teal bg) + make/model/plate/badges
- 2×2 grid: בעלים | טסט | ק"מ בטסט | תוקף
- Usage type: GREEN card if private, RED card if lease/rental/taxi/lesson
- Safety rating section
- Recall: RED banner if active, GREEN if none
- Disclaimer: "נתונים רשמיים ממשרד התחבורה · data.gov.il"
**10 · ChatScreen**
- Header: back + seller avatar + name + verified shield + car subtitle
- Messages: right=buyer (teal bubble), left=seller (grey bubble)
- Timestamp separators (e.g. "היום 14:02")
- Info banner: "שיחה מול בעלים פרטי מאומת"
- Fixed input bar + send button
- Firestore real-time stream on messages subcollection
**11 · InspectorsScreen**
- "בודקי רכב קרובים"
- Sorted by distance from user location
- InspectorCardWidget: avatar + name + title + price + stars + reviews + availability badge
- Availability: "פנוי עכשיו" (green) | "בעוד שעה" (amber)
- → "הזמן בדיקה" button on each card
**12 · BookInspectionScreen**
- Inspector summary at top
- Car info (auto-filled, teal background card)
- Time slot selector (3 options)
- Inspection topic pills: מנוע | גוף | בלמים | מיזוג | חשמל | גלגלים
- Price summary: inspection + travel (חינם) + total
- "אשר הזמנה · ₪X" primary button
- Note: "התשלום יתבצע רק לאחר הבדיקה"
**13 · SwipePrefsScreen**
- "מה אתה מחפש?"
- Budget slider with live ₪ readout
- Car type multi-select pills
- Min year selector
- → "התחל לגלות רכבים" button
**14 · SwipeScreen**
- Top bar: filter icon | "גלה רכבים" | chat icon
- Card with car photo + verified badge + match % + car info at bottom
- ✕ red button (skip) | ℹ️ button (→ CarDetailScreen) | ❤️ teal button (like)
- Right swipe = like, left swipe = skip
**15 · MatchScreen**
- Full screen: gradient #0B3D33 → #0F6E56
- Small label: "שני הצדדים מתעניינים"
- Large: "יש התאמה!"
- Overlapping avatars: buyer + heart icon + car
- Car info card (white, 97% opacity)
- "שלח הודעה ראשונה" (white button → ChatScreen)
- "המשך לגלות" (outline → SwipeScreen)
**16 · SavedScreen**
- "רכבים שמורים"
- Empty state: heart icon + "עדיין לא שמרת רכבים" + browse CTA
- Filled: same CarCardWidget as HomeScreen
**17 · NotificationsScreen**
- "התראות"
- BonnetCheck bell notifications: review requests (→ QuickReviewScreen)
- Chat message previews
- Unread = bold + green dot
**18 · QuickReviewScreen**
- "עזרה למישהו שעומד לראות רכב"
- Car info card (the car they previously inspected)
- Info banner: "אתה לא חייב לקנות כדי לעזור"
- "למה לא קנית?" pills: הטריד אותי | מצאתי אחר | המחיר
- Text area: "מה כדאי שידע?"
- Anonymous toggle (checked by default)
- "שלח עזרה" + "דלג" ghost
- ⚠️ CRITICAL: reviews have NO sellerId field. Seller NEVER sees this.
---
### ד — SELLER (4 screens)
**19 · SellerHomeScreen** (seller's Tab 1)
- "שלום, [name]" + "מרכז המוכר"
- Active listing card → MyListingScreen
- Red warning card if listing removed
- Tips: photo tip, response time tip
- Bottom TabBar (seller): בית | המודעה | פרסום | צ'אטים | פרופיל
**20 · CreateListingScreen** (3 steps)
- Step 1: Photo upload grid (up to 12, first = cover)
- Step 2: Auto-filled plate info (read-only from verification) + price + km (editable) + area dropdown + reason textarea
- Step 3: Review + "פרסם מודעה" + note "תג מוכר מאומת יוצג אוטומטית"
- Success screen after publish: 0 views / 0 saves / 0 messages
**21 · MyListingScreen**
- Listing thumbnail + title + price + days active
- Stats row: 👁 views | ❤️ interested | ★ reviews
- "מי מתעניין ברכב שלך" list:
  - buyer avatar + name + match badge (if matched) + budget + area + chat icon
  - Green dot = new unread message
**22 · ListingRemovedScreen**
- RED warning box: "המודעה הוסרה"
- Reason: "בעקבות דיווחים חוזרים על אי-התאמה"
- Struck-through car card
- 3 bullet points explaining why
- "להגיש ערעור" (secondary) + "חזרה" (ghost)
---
### SHARED (2 screens)
**23 · ChatListScreen**
- "צ'אטים"
- Rows: avatar + verified shield + name + preview + timestamp
- Bold = unread
- Swipe to delete
**24 · ProfileScreen**
- Large avatar + name + verified badge
- Stats: listings | reviews | rating
- Menu rows: המודעות שלי | שמורים | סטטוס אימות | אודות BonnetCheck | הגדרות
- AboutScreen: teal header + shield + "הכוח בידיים שלך" + 4 trust layers
---
## BUSINESS LOGIC RULES
```
RULE 1 — SELLER GATE
  Only users with verified: true in Firestore can access CreateListingScreen.
  Check in go_router redirect. Redirect unverified sellers to VerifyRoleScreen.
RULE 2 — ONE ACTIVE LISTING
  Each seller: max 1 car with status 'active' at a time.
  Enforce with Firestore query before creating.
RULE 3 — AUTO-REMOVAL (3 reports)
  Cloud Function: onDocumentCreated('reports/{id}')
  Count reports for same carId.
  If count >= 3 → set car.status = 'removed' → FCM push to seller.
RULE 4 — MATCH MECHANISM
  Buyer swipes right → write to cars/{carId}/buyer_likes/{buyerId}
  Cloud Function: check if seller has liked same buyer
  If yes → create matches/{id} + chats/{id} → FCM push to both.
RULE 5 — KM VALIDATION (anti-fraud)
  When seller enters current KM:
  Must be >= km_acharon_tirut from data.gov.il
  If lower → show error: "⚠️ הקילומטראז' שהוזן נמוך מהטסט האחרון (X ק"מ)"
RULE 6 — ANONYMOUS REVIEWS
  Cloud Function: notify_prev_viewers
  When buyer schedules a visit → find all previous visitors to same plate
  Send FCM → QuickReviewScreen
  Reviews stored WITHOUT sellerId. Seller cannot query or see them.
RULE 7 — INSPECTOR ESCROW
  Payment charged at booking time.
  Released to inspector only after buyer confirms: "הבדיקה בוצעה ✓"
```
---
## CLOUD FUNCTIONS (functions/index.js)
```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();
// 1. Verify plate against data.gov.il
exports.verifyPlate = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated');
  const plate = data.plate.replace(/-/g, '');
  const url = `https://data.gov.il/api/3/action/datastore_search?resource_id=053cea08-09bc-40ec-8f7a-156f0677aff3&q=${plate}&limit=1`;
  const res = await fetch(url);
  const json = await res.json();
  const records = json?.result?.records;
  if (!records || records.length === 0) {
    throw new functions.https.HttpsError('not-found', 'Plate not found');
  }
  return records[0];
});
// 2. Auto-remove listing after 3 reports
exports.autoRemoveListing = functions.firestore
  .document('reports/{reportId}')
  .onCreate(async (snap) => {
    const { carId } = snap.data();
    const reports = await db.collection('reports').where('carId', '==', carId).get();
    if (reports.size >= 3) {
      await db.collection('cars').doc(carId).update({ status: 'removed' });
      const car = await db.collection('cars').doc(carId).get();
      const { sellerId } = car.data();
      const user = await db.collection('users').doc(sellerId).get();
      // Send FCM push to seller
      const tokens = user.data().fcmTokens || [];
      if (tokens.length > 0) {
        await admin.messaging().sendMulticast({
          tokens,
          notification: {
            title: 'המודעה שלך הוסרה',
            body: 'בעקבות דיווחים חוזרים על אי-התאמה'
          }
        });
      }
    }
  });
// 3. Create match when both sides like each other
exports.createMatch = functions.firestore
  .document('cars/{carId}/buyer_likes/{buyerId}')
  .onCreate(async (snap, context) => {
    const { carId, buyerId } = context.params;
    const car = await db.collection('cars').doc(carId).get();
    const sellerId = car.data().sellerId;
    // Check if seller also liked this buyer
    const sellerLike = await db
      .collection('cars').doc(carId)
      .collection('seller_likes').doc(buyerId).get();
    if (sellerLike.exists) {
      const chatRef = db.collection('chats').doc();
      await chatRef.set({ participants: [buyerId, sellerId], carId, createdAt: admin.firestore.FieldValue.serverTimestamp() });
      await db.collection('matches').add({
        carId, buyerId, sellerId, status: 'matched',
        chatId: chatRef.id, createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
      // FCM to both
    }
  });
// 4. Notify previous viewers when new buyer wants to visit
exports.notifyPrevViewers = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated');
  const { carId } = data;
  const visits = await db.collection('visits').where('carId', '==', carId).get();
  const prevVisitorIds = visits.docs
    .map(d => d.data().userId)
    .filter(id => id !== context.auth.uid);
  for (const uid of prevVisitorIds) {
    const user = await db.collection('users').doc(uid).get();
    const tokens = user.data()?.fcmTokens || [];
    if (tokens.length > 0) {
      await admin.messaging().sendMulticast({
        tokens,
        notification: {
          title: 'BonnetCheck',
          body: 'מישהו הולך לראות את הרכב שבדקת. יש לך כמה מילים בשבילו?'
        },
        data: { screen: 'quick_review', carId }
      });
    }
  }
});
```
---
## DATA MODELS (complete Dart)
```dart
// lib/data/models/user_model.dart
enum UserRole { buyer, seller, inspector }
class UserModel {
  final String uid;
  final String name;
  final String phone;
  final UserRole role;
  final bool verified;
  final double rating;
  final DateTime createdAt;
  final List<String> fcmTokens;
  const UserModel({
    required this.uid, required this.name, required this.phone,
    required this.role, required this.verified, required this.rating,
    required this.createdAt, this.fcmTokens = const [],
  });
  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      role: UserRole.values.firstWhere((r) => r.name == data['role'], orElse: () => UserRole.buyer),
      verified: data['verified'] ?? false,
      rating: (data['rating'] ?? 0.0).toDouble(),
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      fcmTokens: List<String>.from(data['fcmTokens'] ?? []),
    );
  }
  Map<String, dynamic> toFirestore() => {
    'name': name, 'phone': phone, 'role': role.name,
    'verified': verified, 'rating': rating,
    'createdAt': createdAt, 'fcmTokens': fcmTokens,
  };
}
```
```dart
// lib/data/models/car_model.dart
enum CarStatus { active, removed, sold }
class CarModel {
  final String id;
  final String plate;
  final String make;
  final String model;
  final int year;
  final double price;
  final int km;
  final int hand;
  final String area;
  final String sellerId;
  final CarStatus status;
  final Map<String, dynamic>? govData;
  final List<String> photos;
  final String reasonForSelling;
  final DateTime createdAt;
  const CarModel({
    required this.id, required this.plate, required this.make,
    required this.model, required this.year, required this.price,
    required this.km, required this.hand, required this.area,
    required this.sellerId, required this.status, this.govData,
    required this.photos, required this.reasonForSelling,
    required this.createdAt,
  });
  factory CarModel.fromFirestore(Map<String, dynamic> data, String id) {
    return CarModel(
      id: id,
      plate: data['plate'] ?? '',
      make: data['make'] ?? '',
      model: data['model'] ?? '',
      year: data['year'] ?? 0,
      price: (data['price'] ?? 0).toDouble(),
      km: data['km'] ?? 0,
      hand: data['hand'] ?? 1,
      area: data['area'] ?? '',
      sellerId: data['sellerId'] ?? '',
      status: CarStatus.values.firstWhere(
        (s) => s.name == data['status'], orElse: () => CarStatus.active),
      govData: data['govData'],
      photos: List<String>.from(data['photos'] ?? []),
      reasonForSelling: data['reasonForSelling'] ?? '',
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }
  Map<String, dynamic> toFirestore() => {
    'plate': plate, 'make': make, 'model': model, 'year': year,
    'price': price, 'km': km, 'hand': hand, 'area': area,
    'sellerId': sellerId, 'status': status.name, 'govData': govData,
    'photos': photos, 'reasonForSelling': reasonForSelling,
    'createdAt': createdAt,
  };
}
```
---
## ROUTING (go_router)
```dart
// lib/app/router.dart
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      // Add auth redirect logic here
      return null;
    },
    routes: [
      // Auth
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      // Verify
      GoRoute(path: '/verify/role', builder: (c, s) => const VerifyRoleScreen()),
      GoRoute(path: '/verify/plate', builder: (c, s) => const VerifyPlateScreen()),
      GoRoute(path: '/verify/success', builder: (c, s) => const VerifySuccessScreen()),
      // Buyer shell (with bottom TabBar)
      ShellRoute(
        builder: (c, s, child) => BuyerShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
          GoRoute(path: '/saved', builder: (c, s) => const SavedScreen()),
          GoRoute(path: '/discover', builder: (c, s) => const SwipePrefsScreen()),
          GoRoute(path: '/chats', builder: (c, s) => const ChatListScreen()),
          GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
        ],
      ),
      // Car screens (no TabBar)
      GoRoute(path: '/car/:id', builder: (c, s) => CarDetailScreen(carId: s.pathParameters['id']!)),
      GoRoute(path: '/car/:id/history', builder: (c, s) => VehicleHistoryScreen(carId: s.pathParameters['id']!)),
      GoRoute(path: '/chat/:chatId', builder: (c, s) => ChatScreen(chatId: s.pathParameters['chatId']!)),
      GoRoute(path: '/inspectors/:carId', builder: (c, s) => InspectorsScreen(carId: s.pathParameters['carId']!)),
      GoRoute(path: '/book/:inspectorId', builder: (c, s) => BookInspectionScreen(inspectorId: s.pathParameters['inspectorId']!)),
      GoRoute(path: '/swipe', builder: (c, s) => const SwipeScreen()),
      GoRoute(path: '/match', builder: (c, s) => const MatchScreen()),
      GoRoute(path: '/notifications', builder: (c, s) => const NotificationsScreen()),
      GoRoute(path: '/review/:carId', builder: (c, s) => QuickReviewScreen(carId: s.pathParameters['carId']!)),
      // Seller shell
      ShellRoute(
        builder: (c, s, child) => SellerShell(child: child),
        routes: [
          GoRoute(path: '/seller', builder: (c, s) => const SellerHomeScreen()),
          GoRoute(path: '/seller/listing', builder: (c, s) => const MyListingScreen()),
          GoRoute(path: '/seller/create', builder: (c, s) => const CreateListingScreen()),
          GoRoute(path: '/seller/removed', builder: (c, s) => const ListingRemovedScreen()),
        ],
      ),
      // Shared
      GoRoute(path: '/about', builder: (c, s) => const AboutScreen()),
    ],
  );
});
```
---
## CODING RULES — READ BEFORE EVERY FILE
```
1.  Write COMPLETE files — no // TODO, no // implement, no placeholder comments
2.  Every screen: 3 states — loading (CircularProgressIndicator), error (red banner + retry), success
3.  Use Riverpod AsyncNotifier for all async state — never setState in screens
4.  All Firestore writes → through Repository classes, never from UI widgets
5.  Hebrew strings → always in AppStrings constants, never hardcoded in widgets
6.  RTL → Directionality(textDirection: TextDirection.rtl) at MaterialApp root
7.  Colors → always AppColors.X — never hardcode hex values in widgets
8.  Plate numbers → strip dashes before API, display with dashes in UI
9.  Dates from API → always YYYYMMDD → use DateFormatter.fromGov(string)
10. Images → compress before upload, max 1MB, use CachedNetworkImage to display
11. go_router ShellRoute → buyer and seller each have their own bottom TabBar shell
12. Build Phase 1 first and confirm it compiles before ANY feature work
13. When fixing a bug → show the complete corrected file, not just the changed lines
14. fcmTokens field → always update in Firestore when FCM token refreshes
```
---
## BUILD PHASES — DO THESE IN ORDER
### Phase 1 — Foundation ✅ START HERE
```bash
flutter create autoproof --org il.autoproof
cd bonnetcheck
```
1. Replace `pubspec.yaml` with the full version above
2. Run `flutter pub get`
3. Run `dart pub global activate flutterfire_cli && flutterfire configure`
4. Create `lib/core/constants/app_colors.dart` (full file above)
5. Create `lib/app/theme.dart` — ThemeData using AppColors
6. Create `lib/app/router.dart` — all routes pointing to empty placeholder screens
7. Create `lib/main.dart` — ProviderScope + MaterialApp.router + RTL
8. Create placeholder `class XScreen extends StatelessWidget` for all 24 screens
9. **Goal:** `flutter run` launches with a white screen and zero errors
### Phase 2 — Auth
- SplashScreen with auto-navigation
- OnboardingScreen (3-slide PageView)
- LoginScreen (Phone OTP)
- AuthProvider + AuthRepository
### Phase 3 — data.gov.il (MVP Feature ①)
- GovApiService with Dio
- GovDataModel with full field mapping
- DateFormatter + PlateFormatter utilities
- VehicleHistoryScreen (search → display)
- Verify plate in VerifyPlateScreen
### Phase 4 — Seller Verification (MVP Feature ②)
- VerifyRoleScreen + VerifyPlateScreen + VerifySuccessScreen
- Write verified:true to Firestore after success
- go_router redirect: block unverified users from /seller/create
### Phase 5 — Car Listing + Buyer Home
- CreateListingScreen (3 steps + photo upload to Storage)
- CarRepository (CRUD)
- HomeScreen (Firestore stream)
- CarCardWidget + CarDetailScreen + SavedScreen
### Phase 6 — Chat (MVP Feature ③)
- ChatRepository (Firestore real-time)
- ChatScreen with message bubbles
- ChatListScreen
- FCM push for new messages
### Phase 7 — Discovery + Match
- SwipePrefsScreen + SwipeScreen
- Cloud Function: create_match
- MatchScreen
- NotificationsScreen + QuickReviewScreen
### Phase 8 — Beta Polish
- InspectorsScreen + BookInspectionScreen
- ProfileScreen + AboutScreen + ListingRemovedScreen
- Error handling on ALL screens
- Loading states on ALL screens
- Cloud Functions: autoRemoveListing + notifyPrevViewers
- TestFlight (iOS) + Play Console (Android)
---
## SUCCESS MILESTONES
| Week | Goal |
|---|---|
| 2 | App launches on Simulator — Splash + Login + Home with Firestore data |
| 5 | Buyer can browse, save cars, and send a message to a seller |
| 8 | Seller passes verification and publishes a listing with photos |
| 11 | Match works — both sides swipe right → chat opens + Push notification |
| 15 | Inspector booking flow complete |
| 18 | Beta live on TestFlight + Play Console — first 50 real users |
---
## START COMMAND
**When I say "start" → begin with Phase 1.**
First output should be:
1. The complete `pubspec.yaml`
2. The complete `lib/main.dart`
3. The complete `lib/app/theme.dart`
4. The complete `lib/core/constants/app_colors.dart`
Then ask me to confirm the app compiles before moving to Phase 2.
Firebase project `bonnetcheck-app` is already created with
Auth, Firestore, Storage, and FCM enabled.
