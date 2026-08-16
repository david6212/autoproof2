> **STATUS as of 2026-08-16: all of it is built and deployed.** Every phase in
> §5 shipped, plus the two things this review said the spec got wrong and had
> to be redesigned — the ownership rule that blocked its own transfer flow, and
> the vehicle document being publicly readable with the seller's purchase price
> on it. Suite went 188 → 272. The nav question in §4.5 was answered: שמורים
> gave up its tab and moved to the Home header.
>
> **The one thing still blocked is not code:** Firebase Storage was never
> provisioned on the project, so receipt and document upload cannot work until
> somebody enables it in the console.
>
> Kept as the record of what was decided and why.

---

# The OtoV spec, read against what BonnetCheck already is

Written 2026-08-13, after David supplied a full build specification titled
"OtoV — Build Specification" and asked to add what is new **without losing what
exists**.

Short version: **the product thinking in that document is excellent and the
closed loop is the right idea. Its build instructions are not — they describe
building a second app from zero.** This file separates the two.

---

## 1. The one instruction that must NOT be followed

§13 Phase 1 opens with:

```
flutter create otov --org il.otov
flutterfire configure   # against project otov-app
```

Followed literally that discards, in one command:

- 23 working screens and ~7,300 lines of screen code
- **188 passing tests** and a clean analyzer
- the six-dataset government engine, with **resource IDs verified against the
  live API** (the spec's own IDs for datasets 2–6 are marked unverified, and at
  least one is wrong — see §4)
- the whole design system built this session: tokens in both themes, the card,
  the chip, the map sheet, the nav bar
- the live deployment at bonnetcheck.web.app, the public GitHub release, the
  Android signing key
- the legal framework and every wording rule protecting the app's claims

None of that is replaced by anything in the spec. **Everything below is an
addition to the existing app.**

---

## 2. What is genuinely new, and worth building

This is the part that matters. The document introduces one real idea and
several features that follow from it.

### The closed loop — the core addition

> buyer buys → car enters "הרכב שלי" → owner logs services for years →
> taps sell → history is already there → next buyer sees a documented car

Today BonnetCheck ends at the sale. The buyer has no reason to open it again.
The passport is what turns a one-time marketplace into something people keep.
**This is the single most valuable thing in the document.**

| # | Addition | Why it earns its place |
|---|---|---|
| N1 | **Vehicle passport** — `vehicles/{id}` + `services` subcollection, private per owner | The retention engine. Nothing else here works without it |
| N2 | **Append-only service records** — no edit, no delete, ever | This is the *only* reason a buyer would believe the history. A log the owner can rewrite is worth nothing |
| N3 | **Ownership transfer** — history follows the car to the next owner | Closes the loop. Also the strongest reason to buy *through* the app |
| N4 | **One-tap sell from the passport** — listing pre-filled, timeline attached | The payoff the owner gets for years of logging |
| N5 | **`תיק מתועד` badge** — ≥3 services spanning ≥6 months | The incentive that makes anyone start logging |
| N6 | **Reminders** — test, timing belt, insurance | The reason to open the app between purchases |
| N7 | **Expense tracking** — spend per year by category | Cheap to build once services exist; makes the passport feel owned |
| N8 | **Days on market** vs model average | Real buyer signal, computed from our own data |
| N9 | **Market price band** — 25th–75th percentile | Honest version of the "מחירון" we could never source. Computed from our own listings, so no licence problem |
| N10 | **Price-drop alerts** on saved listings | Small, and a genuine reason to come back |
| N11 | **Recall watch** — new recall matching a car you own | We already pull recalls per plate; this makes it proactive |

### Product rules in the spec that are already ours, restated

§8 R1 (mark, never block), R3 (append-only), R8 (never certify, never claim
total-loss or lien data) match the wording rules already enforced in
`AppStrings` and the claims audit. Nothing to change; good that they agree.

---

## 3. What already exists — do not build these again

Roughly **half the specification is already shipped.** Building it fresh would
be the most expensive way to end up where we started.

| Spec item | Where it already lives |
|---|---|
| B1 search + filters | `home_screen.dart` + `search_filter_sheet.dart` — now with two-ended typed ranges and 9 colours |
| B2 listing detail | `car_detail_screen.dart` — 14 ordered sections |
| B3 gov data screen | `vehicle_history_screen.dart` + `gov_data_card_widget.dart` |
| B4 buyer guide, 4 steps, saved progress | `buyer_journey_card.dart`, progress at `cars/{id}/journeys/{uid}` |
| B5 stations map, 134 stations, town-centre caveat | `inspectors_screen.dart` — **already geocoded, 107 street-level**, caveat already displayed |
| B6 saved listings | `saved_screen.dart` |
| B7 compare | `compare_screen.dart` — with the no-winner rule the spec does not mention |
| D1 create listing | `create_listing_screen.dart`, 3 steps + odometer dialog |
| D2 my listings | `my_listing_screen.dart` |
| E1/E2 chat | `chat_list_screen.dart`, `chat_screen.dart` |
| E3 profile | `profile_screen.dart` |
| E4 fuel stations | `fuel_stations_screen.dart` — with the draggable map sheet |
| R1 seller type + community reports | `SellerTypeBadge` + `seller_encounter_card.dart` (tally, majority, disagreement banner) |
| R2 rollback, **both checks** | `plate_history_card.dart` — gov anchor *and* community snapshots |
| Anonymous plate snapshots | `plate_history/{plate}/snapshots` — already carries no seller identity |
| Visitor notes with right of reply | `car_notes_section.dart` |
| Six gov datasets | `api_constants.dart` — all six, verified |

---

## 4. Conflicts and errors in the spec — decisions needed

### 4.1 Cloud Functions need the paid plan — the real blocker
All seven functions in §9 require **Blaze**. We are on **Spark**. This affects
N3, N6, N10, N11.

**Good news, and it changes the plan:** almost all of it works without
functions.

| Function | Without Blaze |
|---|---|
| reminder dispatch | Compute due dates client-side, show them in the app. **No push** |
| recall watch | Check on app open — we already query recalls per plate |
| ownership transfer | Client-side write under security rules. Slightly weaker atomicity |
| snapshot on publish | **Already done client-side** at publish time |
| market stats | Compute from the listing stream we already hold |
| price drop | Needs a server to notice a change while the app is closed. **Push blocked** |
| nightly gov refresh | Fetch on open instead — the current behaviour |

So the passport, the loop, the badge, the price band and days-on-market are all
buildable **now**. Only real push notifications need Blaze — and note
`firebase_messaging` is in pubspec but has never been imported, so there is no
push today either way.

### 4.2 Brand — the spec is one rename behind
It says OtoV, otov.co.il, and a cream `#F5F0E8` palette. The app was renamed
**AutoProof → KLARO → OtoV → BonnetCheck**, and this session rebuilt the whole
palette around `tealFill #1E6B45` on a light background, with 24 tokens in two
themes and contrast pinned by tests. **Recommendation: keep BonnetCheck and the
current palette.** Adopting the spec's colours means redoing the restyle,
including the light app bar and nav bar David just approved.

### 4.3 `listings` vs `cars`
The spec calls the collection `listings`. Ours is `cars`, with subcollections
`notes`, `encounters`, `journeys`, `reports`. Renaming means migrating live
data, rewriting every repository and the security rules, for **zero** user
benefit. **Recommendation: keep `cars`.** Where the spec says `listings`, read
`cars`.

### 4.4 A wrong dataset ID
Spec §6 gives garages/inspection stations as `d4b02ec4-b5f9-42ed-a97e-1e3c6a2a52e3`.
Ours, verified and in production, is **`bb68386a-a331-4bbc-b668-bba2766d517d`**
— filtered on `miktzoa == "בדיקות-רכב )קניה ומכירה)"` (note the reversed
parenthesis; exact match required). Keep ours. The spec's other IDs 2–6 happen
to match ours, and it admits they are unverified.

### 4.5 Four tabs vs five
Spec: `חיפוש · הרכב שלי · צ'אטים · פרופיל`. Ours: `בית · שמורים · דלק · צ'אטים
· פרופיל`. The passport genuinely deserves a tab. **Something has to give — the
decision is David's**, and it is the one question worth answering before Phase 1
of the additions. Options: move דלק into the profile as the spec does; or move
שמורים there instead, keeping דלק, which was built more recently and is a
reason to open the app.

### 4.6 Statistics need data we do not have yet
Price band and days-on-market both need **≥8 comparable listings**, and the
spec is right to hide them below that. We currently have **4 demo cars**. Both
features will build correctly and then show nothing until there is real volume.
Build them, expect them invisible, and do not treat that as a bug.

### 4.7 Flutter package versions
Spec pins `flutter_map: ^7.0.0` and `latlong2: ^0.9.0`. We run **8.3.1 / 0.10.1**
with clustering verified against real coordinates for zero overlap at every
zoom. **Do not downgrade.**

---

## 5. The plan, as additions

Phases here replace §13 entirely. Each is shippable on its own.

**P1 · Passport foundation** — `Vehicle` + `ServiceRecord` models,
`VehicleRepository` **exposing no update or delete for services**, security
rules, `vehicles` collection. Nav decision from §4.5 applied.

**P2 · Passport UI** — garage screen, add vehicle (plate → existing gov lookup →
confirm), vehicle detail with its four tabs, add service with receipt upload.
Reuses `SpecTile`, `RecordRow`, `AppCard`, the gov engine — all already built.

**P3 · Reminders and expenses** — client-side computation, in-app surfacing.
Note plainly in the UI that there is no push yet, rather than implying there is.

**P4 · The loop** — one-tap publish from a vehicle, `תיק מתועד` badge on the
card (the card already has a chip row for it), mark-as-sold with buyer
selection, ownership transfer, inherited history on the buyer's side.

**P5 · Intelligence** — days on market, market price band, price-drop
indicator on the saved list. All client-side, all hidden under 8 samples.

**P6 · Blaze decision** — only if David wants real push. Everything above ships
without it.

---

## 6. What I would do first

The nav question in §4.5, because Phase 1 cannot be laid out without it — and
then P1 and P2, which is the whole passport and the reason to do any of this.
