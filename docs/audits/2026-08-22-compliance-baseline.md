<!-- Written by the parent session from the compliance-auditor agent's final
     message. The auditor is read-only and cannot write files; its transcript
     was cleaned from disk before it could be extracted programmatically, so
     this is a transcription of the message it returned.
     Agent run: 2026-08-22, 111 tool calls, ~20 minutes. -->

# BonnetCheck — Full Baseline Compliance Audit

**Auditor:** Compliance Auditor (read-only). **Date of audit:** 2026-08-22. **All provider terms fetched 2026-08-22 unless stated.**
**Repository:** `C:/Users/DAVID/dev/autoproof` @ `64e3035`. **Live:** https://bonnetcheck.web.app. **Firebase:** `autoproof-8d827` (Spark, Firestore `eur3`).
**Regulatory scope audited:** stricter of Israeli Privacy Protection Law 5741-1981 (as amended by Amendment 13, in force 14/08/2025) and GDPR/ePrivacy. **Stores:** Google Play + Apple App Store.

I did not sample. Every surface in the registry was examined. What I could not verify is listed in §4 and is never counted as compliant.

---

## 1. Verdict summary

| Verdict | Count |
|---|---|
| **HALT** | **11** |
| **NEEDS CHANGE** | **17** |
| **COMPLIANT (verified)** | **19** |
| **UNVERIFIED** | **9** |

Your ten suspicions: **9 confirmed, 1 dismissed (item 7, the refinery price — it is labelled correctly).** One finding you did not suspect is more severe than all ten.

---

## 2. HALT — every one, most severe first

### HALT-1 · The live marketplace publishes four fabricated listings against four real, currently-registered Israeli vehicles

**Surface:** Firestore `cars/*` on the production project, served to the public at `https://bonnetcheck.web.app/app/`.

**What I did.** Anonymous, unauthenticated HTTP GET against the production Firestore REST API (2026-08-22):

```
GET https://firestore.googleapis.com/v1/projects/autoproof-8d827/databases/(default)/documents/cars?pageSize=100
→ 200, 4 documents, all status="active", all sellerId="demo-seller"
plates: 4659255 · 3780034 · 20837803 · 67688002
```

I then put each plate through your own live Cloudflare Worker into the Ministry of Transport registry (`resource_id=053cea08-…`, exact `filters`), 2026-08-22:

| Plate | Registry says | Listing says |
|---|---|---|
| 4659255 | מזדה KF6W7, 2017, **בעלות: פרטי** | ₪98,000 · רמת גן · "ללא תאונות… בעל יחיד, לא מעשן" |
| 3780034 | יונדאי J3813, 2015, **פרטי** | ₪79,000 · חיפה · sellerType **`agent`** |
| 20837803 | סקודה NX33LD, 2022, **פרטי** | ₪132,000 · "טופלה בזמן" |
| 67688002 | ב.מ.וו 5Y91, 2021, **פרטי** | ₪189,000 · sellerType **`dealer`** |

All four are live, active, public, and describe a **privately-owned car that is not for sale** as being for sale, with fabricated factual claims about its accident history and service record — and two of them fabricate the seller classification, the single field the entire product exists to be honest about.

**Rules broken.**

1. data.gov.il licence, §"שימושים אסורים", https://data.gov.il/he/terms-of-use (page updated 30/08/2025; fetched 2026-08-22 via a rendered browser — `curl` and WebFetch both return an empty shell, exactly the failure mode in your brief):
   > "אינך רשאי לעשות במידע את השימושים הבאים: להציג את המידע באופן מטעה ו/או באופן הגורם למצג שווא… לעשות שימוש שיביא לפגיעה בפרטיותו של אדם, לרבות על ידי הצלבת המידע עם מקורות מידע אחרים."

   Attaching a fabricated sale advertisement to a real registry record is *both* prohibited uses at once: a false representation built from the data, and a privacy harm produced by cross-referencing the registry with another source. §"הפרה" of the same licence: **"הפרת רישיון זה על ידך תביא לסיומו המיידי."** The licence terminates on breach. That is the entire product.

2. Israeli PPL 5741-1981 §2(4) and §2(9) — publishing information about a person's private affairs, and using information received for a purpose other than the one for which it was given.

3. GDPR Art. 5(1)(d) (accuracy) and Art. 6 (no lawful basis) for the four registered keepers, who are identifiable via the plate.

4. Apple App Store Review Guidelines §5.1.2(i), https://developer.apple.com/app-store/review/guidelines/ (fetched 2026-08-22): *"Unless otherwise permitted by law, you may not use, transmit, or share someone's personal data without first obtaining their permission."*

5. Google Play Deceptive Behavior — fabricated user-generated content presented as genuine listings.

**Compounding defect.** `firestore.rules` line `allow update, delete: if isSignedIn() && resource.data.sellerId == request.auth.uid`. `sellerId` is the string `demo-seller`, which is not a Firebase uid and can never equal `request.auth.uid`. **No client can remove these four documents.** Your own published removal policy (`legal_docs.dart` §_removal 1: "מודעה שפורסמה בלי הרשאת בעל הרכב") promises a remedy the database structurally cannot deliver for exactly the listings that need it.

**Failure scenario.** A registered keeper of 67688002 searches their own plate — a thing your app teaches guests to do on the first screen (`guest_garage_intro.dart:119`) — and finds their BMW advertised for ₪189,000 by a "dealer", with a description of its service history written by someone who has never seen it. They complain to the Privacy Protection Authority and to the Ministry of Transport. The Ministry's remedy is termination of the licence under §"הפרה"; the PPA's is an administrative fine under Amendment 13.

**Compliant alternative.** Demo data must use plates that return **zero records** from the registry — the licence permits synthetic data explicitly (§"מאגרי מידע סינתטיים"), and the registry itself tells you which plates are unallocated. Any seeded listing must additionally be flagged in the document and rendered as a demonstration, not as a listing. Removal must not depend on `sellerId == uid`.

---

### HALT-2 · Every plate on the marketplace is world-readable in cleartext; the UI masking is cosmetic

**Surface:** `firestore.rules` `match /cars/{carId} { allow read: if true; }` + `car_model.dart:186` `'plate': plate`.

**Verified live, anonymous, 2026-08-22.** The GET above returned `plate = 4659255` etc. in plain text with no credential of any kind. `lib/presentation/widgets/plate_text.dart` masks the digits on screen; the database hands them to anyone with `curl`.

**Rules.** GDPR Art. 32(1) (security appropriate to the risk) and Art. 25(2) (data protection by default — "by default, personal data are not made accessible without the individual's intervention to an indefinite number of natural persons"). A plate is an identifier that the state links to a named keeper, so it is personal data (Recital 26). Israeli PPL §17 (database security duty), materially strengthened by Amendment 13.

Also, and independently: data.gov.il licence §"שימושים אסורים" — *"לעשות שימוש שיביא לפגיעה בפרטיותו של אדם, לרבות על ידי הצלבת המידע עם מקורות מידע אחרים."*

**Failure scenario.** One `curl` loop produces a CSV of every plate on the platform joined to price, mileage, area, and `sellerId`. Today that is 4 seeded rows. The day the first real seller publishes, it is their car and their uid.

**Compliant alternative.** The plate must not sit in a world-readable document. Options: hold it in a sibling document gated to the seller and to server-side code; or store only a salted hash of it in `cars/*` and resolve the registry lookup through a trusted server (which the Spark plan does not allow today — that constraint is the real blocker and should be named as such).

---

### HALT-3 · `plate_history` is a public, plate-keyed database of vehicle histories

**Surface:** `firestore.rules` `match /plate_history/{plate}/snapshots/{snapshotId} { allow read: if true; }`.

**Verified live, anonymous, 2026-08-22:**
```
GET .../documents/plate_history/4659255/snapshots?pageSize=5
→ 200 {"documents":[{... area:"חיפה", km:61000, price:105000, sellerType:"dealer", createdAt:2023-09-01 ...}]}
```
The top-level collection is correctly unlistable (403), so this is not enumerable — but the document key **is the plate**, and plates are visible on every car in every street. Anyone can walk a car park and build a price/mileage history for each vehicle they photograph.

**Rules.** Same as HALT-2, plus your own privacy policy §7 (`legal_docs.dart:216-218`): *"תיעוד זה אינו כולל את שמכם או כל פרט מזהה שלכם."* That sentence is inaccurate — the plate is the primary key of the record. Under GDPR Recital 30 and Art. 4(1), a persistent identifier tied to a specific vehicle whose keeper the state can name is personal data. This breaches **LOCKED DECISION 1** (never make a claim the code does not perform) inside the privacy policy itself.

**Compliant alternative.** Key the collection on a keyed hash (HMAC) of the plate with a secret the client does not hold, so a lookup requires the app rather than a guess — or gate the read behind authentication plus rate limiting, and correct §7 of the privacy policy either way.

---

### HALT-4 · Google Analytics fires and sets cookies before any consent, for EU users

**Surface:** `firebase_analytics` via `lib/presentation/providers/analytics_provider.dart`, wired into GoRouter as a global observer.

**Verified live in a real browser at https://bonnetcheck.web.app/app/, 2026-08-22.** On first load, before any interaction, still on `/splash`:

```
https://www.googletagmanager.com/gtag/js?l=dataLayer&id=G-RC1YMEXY1Y
https://www.google-analytics.com/g/collect?…&en=page_view&cid=31590859.1787174085&_fid=fq4nQT3B…
https://www.google-analytics.com/g/collect?…&en=screen_view&ep.screen_name=%2Fsplash&…
document.cookie → "_ga=GA1.1.31590859.1787174085; _ga_RC1YMEXY1Y=GS2.1.…"
```

There is **no consent mechanism anywhere in the codebase**: `grep -rniE "setAnalyticsCollectionEnabled|consent|optOut" lib/` returns only unrelated hits. The only consent artefact is `_ConsentNote` on the login screen — a passive browse-wrap line ("בהתחברות או בגלישה אתם מאשרים את…") on a screen the analytics hit has already beaten.

**Rules.**
- ePrivacy Directive 2002/58/EC Art. 5(3): storing information on, or gaining access to information already stored in, a subscriber's terminal equipment is permitted only with prior informed consent, except where strictly necessary to provide a service the user explicitly requested. `_ga` is not strictly necessary.
- GDPR Art. 4(11): consent must be "freely given, specific, informed and unambiguous… by a clear affirmative action". A notice on a later screen is none of those.
- Apple App Store Review Guidelines §5.1.1(ii), fetched 2026-08-22: *"Apps that collect user or usage data must secure user consent for the collection, even if such data is considered to be anonymous at the time of or immediately following collection… Apps must also provide the customer with an easily accessible and understandable way to withdraw consent."* There is no withdrawal mechanism.

**Failure scenario.** A German or Irish user complains; the supervisory authority finds a GA4 identifier set with no consent and no opt-out on a service that explicitly names EU users in scope. Separately, App Review rejects under 5.1.1(ii) for the missing withdrawal control.

**Compliant alternative.** Call `FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false)` **before** `runApp`, present a genuine consent choice with a real "decline" that is no harder to press than "accept" (your `ethics_test.dart` already forbids shaming decline buttons — this is the same principle), enable collection only on affirmative consent, and expose a permanent toggle in the profile screen.

---

### HALT-5 · Google Fonts is fetched at runtime, sending every EU user's IP to Google, undisclosed

**Surface:** `lib/app/theme.dart:36,70,88,105` (`GoogleFonts.heeboTextTheme`, `GoogleFonts.heebo`) and `lib/presentation/widgets/brand_logo.dart:155` (`GoogleFonts.poppins`). No font assets are declared in `pubspec.yaml`; there is no `GoogleFonts.config.allowRuntimeFetching = false` anywhere in the tree.

**Verified live, 2026-08-22**, from the same page load:
```
https://fonts.gstatic.com/s/a/ce5bcb350475234d676cdf403a236220232f4bdb091ff8b8108ce825fcb2a989.ttf
https://fonts.gstatic.com/s/a/2c40dd08dd78a0a124003e6bf7eb25051de5b5a498a48324f578874b827c4dff.ttf
https://fonts.gstatic.com/s/a/ed709f2ba2be295030614990104cb4c9c62bc2a2445c25ccb19a1500158a5a8b.ttf
https://fonts.gstatic.com/s/roboto/v32/KFOmCnqEu92Fr1Me4GZLCzYlKw.woff2
```
This is the exact fact pattern of **LG München I, judgment of 20 January 2022, case 3 O 17493/20**, which held that transmitting a visitor's IP address to Google by embedding Google Fonts without consent infringes the visitor's right of personality and awarded damages.

**Rules.** GDPR Art. 6 (no lawful basis — the font is not necessary for the contract and a self-hosted copy is trivially available), Art. 13(1)(e) (recipients must be named — Google Fonts appears nowhere in `legal_docs.dart` §8 or in the published `/legal/privacy/`, which I confirmed by grepping the generated page for "Google Fonts", "gstatic" and "Cloudflare": zero hits), and Art. 44 (transfer to a US recipient without disclosure).

**Note the asymmetry:** the landing site at `/` already does this correctly — it self-hosts `landing/fonts/heebo-hebrew.woff2`, `heebo-latin.woff2`, `poppins-700-latin.woff2` with `@font-face` and a preload. Only the app at `/app/` leaks.

**Compliant alternative.** Bundle the same three woff2/ttf files as Flutter assets, declare them in `pubspec.yaml` under `fonts:`, and drop `google_fonts`. If the dependency is kept for any reason, `GoogleFonts.config.allowRuntimeFetching = false` must be set before the theme is built and the fonts must be bundled — otherwise text silently falls back.

---

### HALT-6 · Neither map shows any OpenStreetMap attribution — ODbL breach and tile-service blocking risk

**Surface:** `lib/presentation/screens/buyer/fuel_stations_screen.dart:228-231` and `lib/presentation/screens/buyer/inspectors_screen.dart:355-358`.

```dart
TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  userAgentPackageName: 'il.autoproof.autoproof',
),
```

`grep -rn "attribution\|Attribution\|RichAttributionWidget\|SimpleAttributionWidget" lib/ --include=*.dart` returns **nothing**. There is no attribution widget, no "©️ OpenStreetMap", no link to openstreetmap.org/copyright, on either map or anywhere else in the app.

**Rules.**
- OSMF Tile Usage Policy, https://operations.osmfoundation.org/policies/tiles/ (fetched 2026-08-22), Requirements: *"Show OpenStreetMap licence attribution clearly on the map (typically bottom-right)."* Enforcement: *"Access may be blocked without prior notice."*
- OSMF Attribution Guideline, https://osmfoundation.org/wiki/Licence/Attribution_Guidelines (adopted 2021-06-25; fetched 2026-08-22): *"Attribution must be presented to anyone who uses, views, accesses, interacts with, or is otherwise exposed to the map or produced work. The attribution format should not require individuals to interact with the map or produced work to see the attribution."* … *"Attribution must be to 'OpenStreetMap'."* … *"Attribution must also make it clear that the data is available under the Open Database License. This may be done by making the text 'OpenStreetMap' a link to openstreetmap.org/copyright."* For interactive maps: *"the credit should typically appear in a corner of the map."*

This is a licence breach under the ODbL, not merely a policy breach: the tiles are a Produced Work used Publicly, and attribution is the condition of that use.

**Failure scenario.** OSMF blocks `il.autoproof.autoproof` at the tile server. Both map screens go blank — the fuel-station map and the inspection-centre map, which is a step in the buyer journey. There is no fallback tile provider in the code.

**Compliant alternative.** Add flutter_map's `RichAttributionWidget` (or a hand-rolled equivalent) to both `FlutterMap` children lists, bottom corner, with the text "© OpenStreetMap contributors" linking to `https://www.openstreetmap.org/copyright`, legible against the tiles in both themes. Fix the User-Agent at the same time (NEEDS-1). If either map is expected to carry real traffic, move off the public tile server entirely — the policy is explicit that it offers no SLA and that *"Commercial services, or those that seek donations, should be especially aware that access may be withdrawn at any point."*

---

### HALT-7 · No in-app account deletion — automatic App Store rejection

**Surface:** `lib/presentation/screens/shared/profile_screen.dart:67-92, 205-212`. The control is labelled `'בקשת מחיקת המידע שלי'` and calls `submitCorrectionProvider(kind: 'account_deletion')`, which writes a document to `data_corrections/*`. That collection is `allow read: if false` in `firestore.rules` — no client can read it. The account is not deleted; the Firebase Auth user is not deleted; a human must notice the row in the Firebase console.

**Rule.** Apple App Store Review Guidelines §5.1.1(v), fetched 2026-08-22: *"If your app supports account creation, you must also offer account deletion within the app."* BonnetCheck supports account creation via phone OTP, Google and Apple.

**Failure scenario.** Rejected on the first submission. This is one of the most consistently enforced items in App Review.

**Compliant alternative.** An in-app action that actually deletes: `FirebaseAuth.currentUser.delete()` plus deletion of `users/{uid}` and its subcollections, with re-authentication where Firebase demands it. The genuine entanglement problem you documented (listings and community reports touch other people's records) is real, but Apple's requirement is that the *account* be deletable in-app; content anonymisation can be the separate, explained step. The current copy ("זו בקשה ולא מחיקה מיידית") is honest and should survive — but it cannot be the whole mechanism.

---

### HALT-8 · iOS declares no usage descriptions for photos or location — guaranteed crash and rejection

**Surface:** `ios/Runner/Info.plist`. `grep -rn "UsageDescription" ios/ macos/` returns **nothing**.

The app uses:
- `ImagePicker().pickImage(source: ImageSource.gallery, …)` at `add_service_screen.dart:64` and `vehicle_detail_screen.dart:453` → requires `NSPhotoLibraryUsageDescription`.
- `Geolocator.requestPermission()` / `getCurrentPosition` at `inspectors_screen.dart:26-36` → requires `NSLocationWhenInUseUsageDescription`.

On iOS, calling a protected API with no purpose string is a hard `SIGABRT` at runtime, not a denied permission.

**Rules.** Apple App Store Review Guidelines §5.1.1(ii), fetched 2026-08-22: *"Ensure your purpose strings clearly and completely describe your use of the data."* And §2.1 (App Completeness) — a crash on a core path.

**Compliant alternative.** Add both keys with specific Hebrew strings that name the actual feature: photos → attaching a service receipt or listing photo; location → showing which inspection centre or fuel station is nearest. Generic strings ("this app needs access to your photos") are themselves a rejection reason. Do not add `NSCameraUsageDescription` — no code path uses `ImageSource.camera`, and adding it would be the same least-privilege error as NEEDS-3.

---

### HALT-9 · `targetSdk = 35` — Google Play stops accepting new apps below API 36 in nine days

**Surface:** `android/app/build.gradle.kts:44` `targetSdk = flutter.targetSdkVersion`; the installed Flutter's `flutter.groovy` sets `targetSdkVersion = 35`.

**Rule.** Google Play target API level requirements, https://support.google.com/googleplay/android-developer/answer/11926878 (fetched 2026-08-22): *"Android 16 (API level 36) August 31, 2026"* is required for new app submissions; existing apps must be at API 35 or higher by the same date to remain visible on newer devices. BonnetCheck is **not yet on Play**, so it is a new app and API 36 applies.

**Failure scenario.** Any first submission on or after 31/08/2026 — nine days from today — is rejected at upload. An extension to 01/11/2026 is available on request, but that is a request, not an entitlement.

**Compliant alternative.** Pin `targetSdk = 36` and `compileSdk = 36` explicitly in `build.gradle.kts` rather than inheriting Flutter's default, and re-test the runtime permission flows (Android 16 tightens foreground-service and photo-picker behaviour, both of which this app touches).

---

### HALT-10 · The Sign in with Apple button draws its own Apple logo

**Surface:** `lib/presentation/screens/auth/login_screen.dart:217` — `leading: Icon(Icons.apple, color: fg, size: 22)`. That is Flutter's Material Icons glyph, not Apple's artwork. Button height is 52 logical px (`_SocialButton`, line 374); title is `'המשך עם Apple'`.

**Rule.** Apple Human Interface Guidelines, Sign in with Apple, https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple (fetched 2026-08-22): *"Use only the logo artwork downloaded from Apple Design Resources; never create a custom Apple logo."* And: *"App Review evaluates all custom Sign in with Apple buttons."* Also *"Titles. Use only Sign in with Apple, Sign up with Apple, or Continue with Apple"* — the Hebrew "המשך עם Apple" is the correct localisation of "Continue with Apple", so the wording is fine; the mark is not. Minimum size 140pt × 30pt is met.

**Failure scenario.** App Review flags the custom button. It is a small fix that costs a full review cycle if found at submission.

**Compliant alternative.** Either use the system-provided button (`ASAuthorizationAppleIDButton` via a platform view / the `sign_in_with_apple` package's `SignInWithAppleButton`), or ship the black and white PNG/SVG logo files from Apple Design Resources as assets and swap `Icons.apple` for `Image.asset`. The existing theme-inverting logic is correct and should be kept — it matches Apple's black-on-light / white-on-dark guidance.

---

### HALT-11 · Storage rules expose vehicle-licence documents to the world — latent until Storage is enabled

**Surface:** `storage.rules`, `match /vehicles/{uid}/{vehicleId}/documents/{fileName} { allow read: if true; … }` and the same on `/receipts/`.

Not live: `AppConfig.storageEnabled = false` and the bucket has never been provisioned. But `firestore.rules` gates the document *metadata* behind `isSharedWithBuyers == true && isListed == true`, with the comment *"A vehicle licence carries an ID number and a home address. Nothing here reaches a buyer until the owner turns sharing on."* The Storage rule contradicts that comment for the file itself. In Firebase Storage rules, `read` covers both `get` and `list`, so the prefix is also enumerable.

**Rules.** GDPR Art. 25(2) and Art. 32; Israeli PPL §17. A רישיון רכב carries a תעודת זהות number and a home address — this is exactly the category the data.gov.il licence itself carves out of scope (§"היקף תחולת רישיון זה": *"נתונים על אישיותו של אדם, מעמדו האישי… כל אלה כמשמעם בחוק הגנת הפרטיות"*).

**Compliant alternative.** Before the first `firebase deploy --only storage`: split listing photos (public read is correct there) from passport documents and receipts (`allow read: if isOwner(uid)`), and serve a shared document to a buyer through a time-limited signed URL minted server-side rather than through a permanently public object. The comment in the rules file about download tokens describes a *different* mechanism than the one the rule actually grants, and should not be relied on.

---

## 3. NEEDS CHANGE — with the precise fix

**NEEDS-1 · OSM User-Agent identifies nothing useful, and is absent entirely on web.**
`flutter_map-8.3.1/lib/src/layer/tile_layer/tile_layer.dart:282-285` sets `'User-Agent': 'flutter_map (il.autoproof.autoproof)'` — **and only `if (!kIsWeb)`**. So the web build at bonnetcheck.web.app sends a plain browser UA with no application identity at all. OSMF policy (fetched 2026-08-22): *"Send a clear, unique User-Agent string that names your app and optionally includes a contact URL or email."* Their example: `MyTownMaps/1.4 (+https://example.org; contact: maps@example.org)`. **Fix:** pass a `NetworkTileProvider(headers: {'User-Agent': 'BonnetCheck/0.5.0 (+https://bonnetcheck.com; support@bonnetcheck.com)'})` on mobile; on web, where the header cannot be set, add the identification the policy's "should" list allows — a contact email published on the site and in the store listing — and treat the web maps as the higher-risk half.

**NEEDS-2 · The privacy policy names the wrong recipients.** `legal_docs.dart` §8 says the plate lookup goes *"מהמכשיר שלכם ישירות לשרתי הממשלה"*. On the web build that is false: `ApiConstants.govApiBase` routes through `https://sweet-breeze-97b0.davidmalede.workers.dev`, which I verified is deployed and live (200 with `Access-Control-Allow-Origin: https://bonnetcheck.web.app`, 403 for a foreign Origin, 2026-08-22). Cloudflare and Google Fonts are both undisclosed recipients. GDPR Art. 13(1)(e). **Fix:** name Cloudflare (Workers, as a CORS relay for web requests) and, until HALT-5 is fixed, Google Fonts, in §8 and in the generated `/legal/privacy/`.

**NEEDS-3 · The privacy policy says you do not collect health data; the code collects it.** §4 (`legal_docs.dart:191`): *"איננו אוספים מידע רפואי. תג נכה הוא מידע שמקורו במאגר ציבורי, אך הוחלט במפורש שלא להציגו."* But `gov_api_service.dart:317` `fetchDisabilityTag()` is called unconditionally on every plate lookup (`gov_api_repository.dart:68`) and the result is stored in `GovData.hasDisabilityTag`. Not displaying it is not the same as not collecting it. The data.gov.il licence §"היקף תחולת רישיון זה" excludes health data from the licence's scope entirely; GDPR Art. 9 treats collection as processing. The comment at `gov_data_card_widget.dart:441` shows the decision was understood and applied one layer too shallow. **Fix:** delete `fetchDisabilityTag`, the `disabilityTagResourceId` constant, the `hasDisabilityTag` field and the `GovDataset.disabilityTag` enum member. Nothing reads it.

**NEEDS-4 · The privacy policy declares a collection that does not happen.** §2: *"התראות: מזהה המכשיר לצורך שליחת התראות."* There is no push. `notifications_screen.dart:24` says so in a comment. Over-declaring is the mirror image of the same problem and will contradict whatever you put on the Play Data Safety form. **Fix:** remove the line when NEEDS-5 is done.

**NEEDS-5 · `firebase_messaging` ships an SDK for a feature that does not exist — and it is not inert.** `pubspec.yaml:` `firebase_messaging: ^15.0.0`; `grep` finds no import in `lib/`. But it *is* registered: `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java:39`, `ios/Runner/GeneratedPluginRegistrant.m:106`, and on web I observed `https://www.gstatic.com/firebasejs/11.9.1/firebase-messaging.js` downloaded on every page load. On Android, FCM auto-init generates a registration token at process start. Google Play Permissions policy, https://support.google.com/googleplay/android-developer/answer/9888170 (fetched 2026-08-22): *"You may not use permissions or APIs that access sensitive information that give access to user or device data for undisclosed, unimplemented, or disallowed features or purposes."* **Fix:** remove the dependency. Re-add it with the feature.

**NEEDS-6 · `ACCESS_FINE_LOCATION` is broader than the feature needs.** `AndroidManifest.xml` declares both FINE and COARSE. The code requests `LocationAccuracy.medium` (`inspectors_screen.dart:34-36`), which is ~100–500 m — precisely what COARSE provides. The feature is "which inspection centre / fuel station is nearest", answered at city-block resolution. Play policy (same URL, fetched 2026-08-22): *"You may only request permissions and APIs that access sensitive information that are necessary to implement current features."* **Fix:** drop the `ACCESS_FINE_LOCATION` line. `geolocator` works on COARSE alone.

**NEEDS-7 · The VIN is shown publicly while the plate is masked.** `gov_data_card_widget.dart:450` renders `('מספר שלדה', data.chassis, true)` from `misgeret`. Any guest who types a plate — which `guest_garage_intro.dart` invites them to do — gets the full chassis number. A VIN is a stronger and more permanent vehicle identifier than a plate and is the key input to plate-cloning fraud. This is internally inconsistent with **LOCKED DECISION 4**. **Fix:** mask or drop the chassis row for anyone who is not the verified owner, the same way `PlateText` does; `plate_privacy_test.dart` should grow a matching scan.

**NEEDS-8 · The cookie policy calls a pseudonymous identifier anonymous.** §2 of `_cookies`: *"Firebase Analytics… שומר מזהה שימוש אנונימי."* The observed `_ga=GA1.1.31590859.1787174085` is a persistent pseudonymous identifier — personal data under GDPR Recital 26/30. Apple §5.1.1(ii) is explicit that consent is required *"even if such data is considered to be anonymous."* **Fix:** call it what it is (מזהה מתמשך / פסאודונימי) and describe its lifetime.

**NEEDS-9 · No GDPR rights section at all.** §10 of the privacy policy cites only the Israeli PPL. For EU users there is no Art. 6 legal basis stated (§6 relies on "עצם השימוש… מהווים הסכמה", which is not valid GDPR consent), no portability (Art. 20), no objection (Art. 21), no restriction (Art. 18), no right to lodge a complaint with a supervisory authority (Art. 13(2)(d)), no Art. 44–49 transfer safeguard for the US-bound Analytics traffic, and no Art. 27 EU representative — which a non-EU controller offering services to EU data subjects must designate in writing. **Fix:** add an EU section covering all of the above, or narrow the stated audience and geo-block, which contradicts the owner's confirmed scope.

**NEEDS-10 · Correction and deletion requests land where nobody can read them.** `data_corrections` and `note_reports` are both `allow read: if false`. The published removal policy and complaints procedure both promise *"נשיב תוך 14 ימים"*, and the only mechanism behind that promise is a human remembering to open the Firebase console. **Fix:** at minimum, mirror each request to `support@bonnetcheck.com`. Until that exists, the 14-day commitment is a claim the system does not perform.

**NEEDS-11 · `tool/gov_cors_proxy.js` header says "NOT DEPLOYED"; it is deployed and serving production traffic.** I verified it live on 2026-08-22 (see NEEDS-2). `api_constants.dart:29` correctly records the 19/08 deployment. Two files in the same repo state opposite facts about a production dependency. **Fix:** correct the header comment. Per your brief, this disagreement is itself the finding.

**NEEDS-12 · Application id and bundle id are `il.autoproof.autoproof`.** `build.gradle.kts:20,43`, `ios/Runner.xcodeproj/project.pbxproj:371,550,572`, and `google-services.json` is keyed to it. Neither store lets you change this after the first release — the Play `applicationId` is permanent for the life of the listing, and an Apple bundle id cannot be reused or renamed. It also appears in the OSM User-Agent (NEEDS-1), where it is the only identity OSMF sees. This is not a rejection risk; it is a **now-or-never** decision that must be settled before the first submission of either store. **Fix:** decide deliberately. If it changes, `google-services.json` and every Firebase app registration change with it, and the debug/release SHA-1 fingerprints must be re-registered (see UNVERIFIED-6).

**NEEDS-13 · Attribution on the fuel and inspection screens names the ministry but not the source.** `fuel_stations_screen.dart:350` `'מקור: משרד האנרגיה'`; `inspectors_screen.dart:447` `'מקור: משרד התחבורה'`. The current licence (§"ציון מקור המידע", updated 30/08/2025) requires only *"עליך לציין את מקור המידע"* — which these arguably satisfy — but the gov data card does it properly (`gov_data_card_widget.dart:218`: `'מקור: מרשם הרכב הממשלתי (data.gov.il)'`). **Fix:** make all three consistent and name data.gov.il. Note that the licence reserves the right to change *"בכל עת, כאשר כל שינוי כזה ייכנס לתוקף מידית"*, and earlier versions required naming the site, the dataset names and their update date — the looser wording is not a guarantee.

**NEEDS-14 · Landing page undercounts the datasets.** `landing/index.html` FAQ: *"חמישה מאגרים של משרד התחבורה לכל רכב"*. The code queries six resource ids for the Ministry of Transport (vehicle, history, recalls, off-road, disability tag, model spec) plus garages, plus two from the Ministry of Energy. `buyer_journey_card.dart:144` also says "5 מאגרי משרד התחבורה". This is understating rather than overstating, so it is not a false claim — but the count should be true, and it will stop being merely understated once the disability dataset is removed per NEEDS-3.

**NEEDS-15 · Google sign-in button asset provenance and padding not confirmed.** `assets/google_g.png` is 192×192, 1510 bytes, rendered at 22×22 on `context.colors.surface`. Google's branding guidelines, https://developers.google.com/identity/branding-guidelines (fetched 2026-08-22): *"Regardless of the text, you can't change the size or color of the Google 'G' logo"*; Android/web padding is specified as 12px before the logo, 10px after, 12px after the text. The label "המשך עם Google" is a permitted localisation of "Continue with Google". **Fix:** confirm the PNG is the unmodified asset from Google's download page and that the button's internal padding matches the spec.

**NEEDS-16 · Cloudflare Workers as a relay is a grey area worth documenting.** Cloudflare Self-Serve Subscription Terms §2.2.1(j), https://www.cloudflare.com/en-gb/terms/ (fetched 2026-08-22), prohibits using the Services *"to provide a virtual private network or other similar proxy services."* Your Worker is origin-allowlisted to five hosts plus loopback, path-allowlisted to one endpoint, GET-only, and serves only your own application — it is not a proxy *service offered to others*, which is what that clause targets. §2.5.4 warrants that Customer Content does not infringe third-party rights; the data.gov.il licence expressly permits copying, distribution and making available (§"שימושים מותרים"), so that warranty holds. **My read is that this is compliant**, but it is a judgement about a clause written for a different fact pattern, so it is recorded here rather than in §5. **Fix:** keep the allowlists narrow (they are), and never widen `ALLOWED_PATHS`.

**NEEDS-17 · Amendment 13 notice obligations not reflected.** The Israeli PPL was amended by Amendment 13, in force 14/08/2025, which restructured the §11 notice-at-collection duty and expanded PPA enforcement powers substantially. Registration (direct-marketing databases over 10,000 people; especially sensitive data on over 100,000) and mandatory DPO appointment (public bodies, data brokers, systematic monitoring, primarily sensitive data) do **not** appear to bind BonnetCheck today. The privacy policy cites "חוק הגנת הפרטיות, התשמ"א-1981" without reflecting the amendment. **Fix:** have counsel confirm the §11 notice content against the amended text — I could not retrieve the statutory text itself and am relying on secondary sources, so treat this as directional, not settled.

---

## 4. UNVERIFIED — what blocked it, and how to close it

| # | What | Why I could not verify | How to close it |
|---|---|---|---|
| U-1 | Whether **Sign in with Apple actually works** — i.e. whether the Apple provider is enabled in Firebase Auth | Console-side. `auth_repository.dart:113` says *"Requires an Apple Developer account + the Apple provider configured in Firebase"*, and `login_screen.dart:86` has a `operation-not-allowed` fallback message, which suggests it may not be. **Guideline 4.8 compliance depends entirely on this**: Google Sign-In is present, so an equivalent login service must actually function, not merely have a button. | Open Firebase console → Authentication → Sign-in method, confirm Apple is enabled with a Service ID and key. Then tap the button on a real build. |
| U-2 | **Play Data Safety form** and **Apple App Privacy** declarations | Console-side, not in the repo. Play requires the declaration to cover *"data collected and handled through any third-party libraries or SDKs"* (https://support.google.com/googleplay/android-developer/answer/10787469, fetched 2026-08-22) with *"blocked updates or removal from Google Play"* for misrepresentation. | Draft both against the actual recipient list after HALT-4/5 and NEEDS-3/5 are fixed — declaring today's behaviour would mean declaring the leaks. |
| U-3 | **Licence of `assets/data/inspection_centers_geo.json`** (11 KB, ~134 geocoded coordinates) | No provenance anywhere in the repo — `grep -rniE "geocod\|nominatim\|photon\|opencage\|google maps"` across all docs returns one line that only says the work was done. If it came from Nominatim, it is an ODbL Derivative Database with attribution and share-alike obligations. If it came from Google's Geocoding API, Google's terms prohibit storing results beyond 30 days and prohibit displaying them on a non-Google map — which is exactly what `inspectors_screen.dart` does. | Ask David which geocoder produced it, or regenerate it from a source with known terms. This is the single largest unknown in the audit. |
| U-4 | Whether the **Firebase API keys** in `firebase_options.dart` are restricted | Console-side. Public exposure of these keys is normal and expected for Firebase; the risk is unrestricted keys being used for quota abuse. | Google Cloud console → APIs & Services → Credentials → application restrictions per platform. |
| U-5 | Whether a **Cloudflare data-processing arrangement** covers EU users' IPs traversing the Worker | Account-side. | Confirm the Cloudflare DPA is in force on the account, then name Cloudflare per NEEDS-2. |
| U-6 | Whether the **release keystore's SHA-1** is registered in Firebase | Console-side. Your own project history records that only the debug keystore was ever registered, which silently broke phone auth and Google Sign-In in release builds. If that is still true, HALT-10's Apple button and the phone OTP flow are both dead in any store build. | Firebase console → Project settings → Android app → SHA certificate fingerprints; compare to `keytool -list` on the release keystore. |
| U-7 | **Live OSM tile traffic and the User-Agent as sent** | The Flutter web app would not render past `/splash` in the browser pane — CanvasKit stops compositing when the pane is not displayed, which matches your existing note on headless screenshots. I confirmed the tile URL, the absent attribution and the `kIsWeb` UA gap from source and from the flutter_map 8.3.1 package source instead. | Run the app on a real device with a proxy, or on a displayed browser pane, and capture a tile request. |
| U-8 | **Apple Developer Program membership / App Store Connect state**, and whether `il.autoproof.autoproof` is already registered as a bundle id | Account-side. Bears directly on NEEDS-12: if the id is already claimed, the decision is already made. | Check App Store Connect → Identifiers. |
| U-9 | Whether the four fabricated listings are **rendered in the app's home feed** | Same rendering blocker as U-7. Firestore says `status: "active"`, `cars_provider` filters on active, and the landing page's own mock shows the same cars — so I assess it as near-certain, but I did not see it on screen. | Open https://bonnetcheck.web.app/app/#/home in a real browser. |

---

## 5. What was checked and found clean (verified, for the next audit to diff)

1. **data.gov.il — commercial use.** §"שימושים מותרים": *"אתה רשאי לעשות שימוש במידע באופן מסחרי ובאופן שאינו מסחרי."* The affiliate-revenue question is **settled: permitted, explicitly, no conditions.** The landing FAQ already says this correctly.
2. **data.gov.il — attribution on the vehicle record.** `gov_data_card_widget.dart:213,218` render "נתונים רשמיים · משרד התחבורה" and "מקור: מרשם הרכב הממשלתי (data.gov.il)". Satisfies §"ציון מקור המידע".
3. **data.gov.il — no-endorsement.** Terms §7 and the landing footer both carry it, matching §"העדר גושפנקא או חסות" almost word for word.
4. **data.gov.il — official publications prevail.** Terms §7, matching §"פרסומים רשמיים של מדינת ישראל".
5. **data.gov.il — as-is disclaimer.** Terms §7 and §9, matching §"מצגים והעדר אחריות".
6. **data.gov.il — no rate limit, no caching prohibition, no anti-intermediary clause.** The licence is silent on all three, so the Worker's `cacheTtl: 600` and `Cache-Control: public, max-age=300` breach nothing.
7. **The refinery price is labelled correctly — your item 7 is dismissed.** `fuel_stations_screen.dart:388-397`: headline says *"בשער בית הזיקוק"*, subline says *"מחיר סיטונאי לפני בלו ומע"מ, לא המחיר במשאבה. מחירי סולר בפועל אינם מפוקחים ואינם מתפרסמים לפי תחנה."* This is exactly what §"שימושים אסורים" (misleading presentation) demands and what consumer-protection expectations require. It is the best-executed disclosure in the app.
8. **Cloudflare Worker behaves as designed, verified live 2026-08-22:** allowed Origin → 200 with a matching `Access-Control-Allow-Origin`; foreign Origin → 403; non-allowlisted path → 404; non-GET → 405. Not an open relay.
9. **Firestore access control on private collections, verified live and anonymous 2026-08-22:** `users` → 403, `vehicles` → 403, `fuel_reports` → 403, `plate_history` top-level list → 403. `transfers` is `get`-only with `list: false`, which is a genuinely good design.
10. **The seller's phone number is not in the public listing document.** Contact runs through `chats`, which is participant-gated. Confirmed by field inspection of live `cars` documents.
11. **Chat security.** Participants fixed at creation; `onlyMyEntry()` prevents one party writing the other's read/delivered/hidden state. The privacy policy correctly discloses that chat is not end-to-end encrypted (§11).
12. **Service records are append-only** (`allow update: if false; allow delete: if false`) and `serviceCount` can only hold or rise by one — the "תיק מתועד" badge cannot be forged.
13. **Location is on-device only.** `userLocationProvider` uses `LocationAccuracy.medium`, returns null on denial, and the value never leaves the device. The privacy policy §3 states this accurately. Play's prominent-disclosure requirement (which attaches to collection) is not triggered.
14. **Analytics never sends the plate.** `analytics_provider.dart:34-38` documents the decision and `vehicleLookup()` sends no parameters. Correct.
15. **The disability tag is deliberately not rendered**, with the reasoning recorded at `gov_data_card_widget.dart:441-444`. The decision is right; only its depth is wrong (NEEDS-3).
16. **Landing site is privacy-clean.** Self-hosted woff2 fonts, no gtag, no pixels, no third-party requests of any kind. `robots.txt` correctly disallows `/app/`.
17. **Legal documents are generated from a single source** (`legal_docs.dart` → `tool/gen_legal.dart` → `landing/legal/*`, run by `build_site.sh` on every deploy), and are live: `https://bonnetcheck.web.app/legal/privacy/` → 200. `LegalInfo.isPublished` correctly gates publication on a real operator name and a real contact address, both of which are set.
18. **`test/ethics_test.dart` enforces the dark-pattern ban across the whole `lib/` tree**, not per screen — no manufactured scarcity, no fake viewer counts, no price advice, no gamification. This is the right shape for a rule that has to survive the next contributor.
19. **`storage.rules` ends with a deny-all catch-all** (`match /{allPaths=**} { allow read, write: if false; }`), and enforces content-type and 10 MB size limits on every write path.

**Scope I deliberately bounded, and did not check:** the Windows, Linux and macOS desktop targets (present in the repo, not shipping); a full SPDX licence audit of the ~200 transitive Dart packages in `pubspec.lock` (I audited the direct dependencies' *use*, not every transitive licence); `BUSINESS_ROADMAP.docx`; the Firebase, Google Play Console and App Store Connect consoles (no access — see §4); and I did not run the test suite, because `flutter test` writes build artefacts and I am read-only.

---

## 6. Prioritized remediation queue

**Stop the line — today, before anything else ships:**

| # | Item | Why first |
|---|---|---|
| 1 | **HALT-1** — remove or replace the four fabricated listings on real plates | Live now. Licence-terminating, and the one finding that could end the product rather than delay it. Fastest fix in the list: delete four documents. |
| 2 | **HALT-2 / HALT-3** — plates and plate history readable by anyone with `curl` | Live now. Today the exposure is four seeded rows; it becomes real personal data the moment a real seller publishes. Fix before the first real listing, not after. |
| 3 | **HALT-4** — gate Firebase Analytics behind real consent | Live now, on every EU visitor, on the splash screen. |
| 4 | **HALT-5** — bundle Heebo and Poppins; drop the runtime fetch | Live now. One-line-per-font fix; the landing site already shows how. |
| 5 | **HALT-6** — OSM attribution on both maps | Live now, and the consequence (silent tile blocking) arrives without warning. |

**Before any store submission:**

| # | Item |
|---|---|
| 6 | **HALT-9** — `targetSdk = 36`. Hard deadline 31/08/2026, nine days out. |
| 7 | **HALT-8** — iOS purpose strings. Without them the app aborts on two paths. |
| 8 | **HALT-7** — real in-app account deletion. |
| 9 | **HALT-10** — Apple's own logo artwork on the Sign in with Apple button. |
| 10 | **U-1** — confirm Sign in with Apple actually functions; guideline 4.8 rests on it. |
| 11 | **NEEDS-12** — settle the `il.autoproof.autoproof` id. Irreversible after the first release. |
| 12 | **U-6** — confirm the release keystore SHA-1 is registered, or phone auth and Google Sign-In are dead in the store build. |
| 13 | **NEEDS-5, NEEDS-6** — drop `firebase_messaging` and `ACCESS_FINE_LOCATION`, then complete **U-2** (Data Safety / App Privacy) against the reduced surface. |

**Policy and disclosure, once behaviour is fixed (a policy written before the fixes would document the leaks):**

| # | Item |
|---|---|
| 14 | **NEEDS-2, NEEDS-3, NEEDS-4, NEEDS-8, NEEDS-9** — one pass over `legal_docs.dart`: correct the recipients, delete the health-data collection and its false denial, delete the notifications claim, stop calling `_ga` anonymous, add the EU rights section. Regenerate `/legal/*`. |
| 15 | **NEEDS-10** — route correction and deletion requests somewhere a human will see them, so the 14-day promise is one the code can keep. |
| 16 | **NEEDS-7** — mask the VIN for non-owners, and extend `plate_privacy_test.dart` to scan for it. |
| 17 | **U-3** — establish the licence of the geocode asset. Unknown provenance on shipped data is the kind of thing that surfaces at the worst moment. |

**Housekeeping, no deadline:** NEEDS-1 (User-Agent), NEEDS-11 (the "NOT DEPLOYED" comment), NEEDS-13 (attribution consistency), NEEDS-14 (dataset count), NEEDS-15 (Google button asset), NEEDS-16 (document the Cloudflare position), NEEDS-17 (Amendment 13 review), HALT-11 (Storage rules — gate this behind the day Storage is enabled, and do not enable it before fixing them), and U-4, U-5, U-8, U-9.

---

**One closing note on method, per the PRIME AXIOM.** Two sources in this audit lied to a server and told the truth to a browser: `data.gov.il/he/terms-of-use` returned an empty document body to both `curl` and WebFetch and rendered its full licence only in a real browser, and the deployed Flutter app renders nothing at all in a non-compositing pane. Every clause quoted above was read from a rendered page or from package source on disk. Nothing here is cited from memory.
