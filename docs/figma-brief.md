# BonnetCheck — visual design critique brief

**What I want from you:** review how this app looks today and propose a sharper,
more polished visual direction. Concentrate on hierarchy, typography, spacing,
colour use, and the design of individual components. Screenshots of every main
screen are attached, in both themes.

**Read section 3 before proposing anything.** It lists decisions that are
already settled and the reasons behind them. Several are legal or ethical
rather than aesthetic, and a proposal that breaks one cannot be used, however
good it looks.

---

## 1. The product

BonnetCheck is a **Hebrew, right-to-left** mobile app for the Israeli
second-hand car market. It cross-references any car listing against the Ministry
of Transport's public vehicle registry, and shows the buyer what the official
record says: mileage at the last inspection, structural damage, open recalls,
ownership history.

Built in Flutter. One codebase runs on Android, iOS and web.

**The product's promise decides more visual questions here than the palette
does:** *we tell you exactly what we checked, and exactly what we did not.*
Anything that looks more certain than the data behind it is off-brand. That one
rule is why findings sit above the specs on a listing, why a section that could
not be verified says so out loud, and why nothing on any screen counts down,
pressures, or implies scarcity.

**Who uses it.** Ordinary people buying a used car — a purchase most make every
few years and never feel confident about. The audience skews older than a
typical consumer app, and many will have the system font size turned up. Trust
matters more than delight; nobody is here to be entertained.

---

## 2. Where I think it is weak

Honest self-assessment. A starting point, not a limit — if you see something
worse than these, say so.

1. **The home feed is dense and flat.** Cards carry a photo, a title, a price,
   several chips and two badges. Everything competes; nothing leads.
2. **Too many chip shapes.** Filter chips, fact chips, badges and status pills
   all look alike but mean different things.
3. **Empty states are plain.** Several screens (saved, compare) show a line of
   text and little else.
4. **The spacing rhythm is inconsistent between screens.** Some feel airy,
   others cramped, with no rule I can point to.
5. **Green is doing a lot of work** — brand, primary action, success and
   emphasis all at once.
6. **Section headers are quiet.** On long screens it is hard to tell where one
   section ends and the next begins.

---

## 3. Constraints — please do not propose changes to these

### 3.1 Language and direction

Hebrew, RTL, everywhere. **Numbers, licence plates and Latin words stay LTR**
inside the RTL layout. Any layout must survive text that runs longer in Hebrew
than in English.

### 3.2 Fonts

Only two are bundled: **Heebo** (all Hebrew and UI text) and **Poppins Bold**
(the Latin wordmark only). No other typeface can be added, and fonts cannot be
fetched at runtime — the app ships them deliberately so that no reader's IP
address reaches a font CDN before the first paint.

**No emoji, and no decorative glyph characters** — no stars, ticks or arrows
typed as text. The bundled fonts do not contain them, and a missing glyph makes
Flutter download a fallback font from Google at runtime, which defeats the whole
reason the fonts are bundled. **Stars, ticks and arrows must be drawn as icons**
(the Material set), never as characters.

### 3.3 The mark

The wordmark reads **"Bonnet"** and a **checkmark finishes the name** — the
check *is* the word "Check", not an ornament beside it. The emblem is a stroked
shield containing a real photograph of a car, with the check on a white circular
badge at the lower right so it never blends into the shield.

Never re-letter the wordmark, redraw the shield as a rounded rectangle, replace
the car photograph with an icon, or move the check away from the end of the word.

### 3.4 Both themes are real

Light and dark are both designed and both shipped; dark is not an afterthought.
The brand green is **identical in both**, so the product looks like itself either
way. Every pale tint in light becomes a deep wash of the same hue in dark, with
its text lightened to match. Any proposal must work in both.

### 3.5 Settled for ethical reasons, not visual ones

These have been considered and rejected. Please do not reintroduce them:

- **No scarcity or urgency.** No "last one", no countdowns, no "3 people
  viewing". Every used car is one unit; presenting that as scarcity is a lie
  told with a true sentence.
- **No score, grade or star rating for a car.** The comparison screen refuses to
  rank cars on purpose. Condensing a registry record into "8.4/10" invents a
  judgement the data cannot support. (Star ratings for *garages* are fine —
  those are real reviews by real people.)
- **No invented precision.** No "1.2 km from you": listings carry a city name,
  not coordinates. No fabricated review counts or activity.
- **A car's licence plate is never shown publicly.** Plates are masked.
- **A section that could not be verified must say so**, rather than being hidden
  or shown as though it had passed.

---

## 4. The design system as it stands today

Extracted from the running code, not written alongside it.

### 4.1 Colour — light theme

| Token | Hex | Role |
|---|---|---|
| `teal` | `#558B6E` | **Identifies** the product: emblem, icons, borders |
| `tealFill` | `#1E6B45` | The green you put **white on**: primary buttons |
| `tealText2` | `#40634F` | Green **ink** on a light surface |
| `tealText` | `#294539` | Darkest green ink, used on green washes |
| `tealLight` | `#E7EFEA` | Pale green wash behind icons and banners |
| `headerTint` | `#EAF3ED` | Header tint |
| `background` | `#F8FAF9` | Page background |
| `surface` | `#FFFFFF` | Cards |
| `cardBorder` | `#E6EAE8` | Hairline borders |
| `pageBackdrop` | `#EDF1EF` | Backdrop behind the app frame on wide screens |
| `textPrimary` | `#1A202C` | Body and headings |
| `textMuted` | `#5A6169` | Secondary text |
| `textSubtle` | `#767C81` | Tertiary text |
| `agentBlue` / `agentBlueBg` | `#3E6DB5` / `#E7EFFA` | "Private seller" |
| `dealerOrange` / `dealerOrangeBg` | `#B4671C` / `#FBEFE0` | "Dealer" |
| `errorRed` / `errorBg` | `#E5604D` / `#FCEBEB` | Errors |
| `warnText` / `warnBg` | `#7A3E0A` / `#FBE7D4` | Warnings |
| `starColor` | `#BA7517` | Rating stars |
| `mintAccent` | `#5DCAA5` | Accent |

### 4.2 Colour — dark theme

`teal`, `tealFill`, white-on-brand and `mintAccent` are **unchanged**.

| Token | Hex |
|---|---|
| `background` | `#101312` |
| `surface` | `#191D1C` |
| `cardBorder` | `#2A302E` |
| `pageBackdrop` | `#0A0C0B` |
| `textPrimary` | `#E8EBEA` |
| `textMuted` | `#A2ABA6` |
| `textSubtle` | `#8A938D` |
| `tealLight` | `#1F2B25` |
| `tealText` / `tealText2` | `#A8CDB8` / `#93BCA5` |
| `headerTint` | `#151C18` |
| `agentBlue` / `agentBlueBg` | `#7FA8E0` / `#1B2534` |
| `dealerOrange` / `dealerOrangeBg` | `#E0A05A` / `#33261A` |
| `errorRed` / `errorBg` | `#F08575` / `#33201E` |
| `warnText` / `warnBg` | `#E5B07A` / `#332819` |
| `starColor` | `#E0A94A` |

**The rule most often got wrong:** `teal` identifies, `tealFill` is what white
sits on, `tealText2` is green ink. White on `teal` fails contrast at 3.96:1, and
a test enforces that it stays unused that way.

### 4.3 Type scale (Heebo)

| Name | Size | Weight |
|---|---|---|
| display | 24 | bold |
| h1 | 22 | bold |
| h2 | 20 | bold |
| h3 | 18 | bold |
| title | 16 | bold |
| subtitle | 15 | bold |
| body | 14 | regular, line-height 1.35 |
| bodySm | 13 | regular, line-height 1.35 |
| caption | 12.5 | regular / w600 |
| micro | 11.5 | regular / bold |
| tiny | 9.5 | bold |

### 4.4 Spacing and radii

**Spacing** is multiples of 4: `2, 4, 8, 12, 16, 24, 32`.
**Radii**: `xs 8`, `sm 12`, `md 14`, `lg 16`, `xl 20`, `pill`.
Pick the nearest existing step; new in-between values are not wanted.

### 4.5 Components already in use

- **AppCard** — the standard surface: white, hairline border, `lg` radius.
- **AppSectionCard** — AppCard plus a header row of icon + title + subtitle.
- **FactChip** — one labelled fact about a car (mileage, seats, gearbox).
- **SpecTile** — a 2-up grid tile. **Every tile names its field**, because an
  unlabelled number is a guess the reader is forced to make.
- **StarRating** — five Material icons.
- **Skeleton** — a shimmering placeholder shown while data loads.

---

## 5. The screens

**Bottom navigation, right to left:** Home · My car · Fuel · Chats · Profile.

| Screen | Hebrew label | What it does |
|---|---|---|
| Home | בית | The listings feed: search, category filter chips, car cards |
| My car | הרכב שלי | Type a plate, get the registry's record; then keep it as a "passport" with service history |
| Fuel | תחנות דלק | All 1,253 public fuel stations on a clustered map, nearest first |
| Chats | צ׳אטים | Buyer and seller messaging |
| Profile | פרופיל | Account, theme, measurement consent, legal |
| Listing detail | — | One car: findings first, then the official record, then specs |
| Compare | השוואת רכבים | Two saved cars side by side — facts only, deliberately no score |
| Saved | רכבים שמורים | Cars kept for later |
| Garages and washes | מוסכים ושטיפות | A community directory with star ratings |
| Inspection centres | מכוני בדיקה | Licensed pre-purchase inspectors, on a map |
| Onboarding | — | Three slides explaining the promise |
| Login | התחברות | Google, or phone. Browsing needs no account at all |

---

## 6. What "better" means here

In priority order:

1. **Hierarchy.** On any screen, what should be read first must look first.
2. **Trust.** It should feel like a document from an authority, not a shopping
   app. Calm, precise, unhurried.
3. **Legibility at large text sizes.** Assume a reader who has turned the system
   text size up by half. Layouts must reflow, never clip.
4. **Fewer, more deliberate visual devices.** If two things look different, they
   should mean different things.
5. **Both themes, always.**

What I do **not** want: a trendy restyle that ages within a year, heavy
gradients, glassmorphism, or anything that makes the data look more certain than
it is.

---

## 7. How to give it back to me

For each screen you rework, say **what you changed and why**, in terms of the
hierarchy or the rules above. A mockup I cannot reason about is a mockup I
cannot ship.

If you break one of my constraints on purpose because you think I am wrong, say
so explicitly rather than quietly.
