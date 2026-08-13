# BonnetCheck — design system brief

Paste this into Claude Design as the source of truth. Everything below is
measured from the shipping Flutter code, not remembered or approximated.

---

## 1. What the product is

BonnetCheck is a used-car marketplace for Israeli buyers. Every listing is
cross-referenced against the Ministry of Transport's public vehicle registry
(data.gov.il): official odometer at last test, structural-change (accident)
flag, open recalls, licence validity, ownership history.

**The promise the design has to keep: we tell you exactly what we checked, and
exactly what we didn't.** The app never claims a car is good. It shows records
and says where they came from. Any visual treatment that blurs the line between
an official record and a user's opinion breaks the product, not just the page.

Sellers are **labelled, not filtered**: private owner / agent / dealer. A dealer
is not a worse listing, only a differently labelled one. Nothing in the UI may
rank seller types.

**Language: Hebrew, RTL.** All UI copy is Hebrew. Component names, code and
comments are English. Latin marks (the wordmark, prices like `₪92,000`) must be
pinned LTR or bidi reordering moves the currency symbol to the wrong end.

**Font: Heebo** for all Hebrew UI. **Poppins 700** for the Latin wordmark only.

---

## 2. Colour tokens

Every token has a light and a dark value. A token with no dark value is a bug.
Widgets never hardcode hex.

| token | light | dark | what it is for |
|---|---|---|---|
| `teal` | `#558B6E` | `#558B6E` | Brand identity: emblem, the wordmark's check, icons, decorative borders. **Identical in both themes** so the product looks like itself in either. |
| `tealFill` | `#4A785F` | `#4A785F` | **Fill under white text** — filled buttons, the app bar. |
| `tealDark` | `#3C614C` | `#2C4A39` | Deeper brand surface, photo scrims. |
| `tealLight` | `#E7EFEA` | `#1F2B25` | Pale wash behind icons and banners; a deep wash in dark. |
| `tealText` | `#294539` | `#A8CDB8` | Ink **on** `tealLight` — inverts with it. |
| `tealText2` | `#40634F` | `#93BCA5` | Green ink on the page: prices, outlined-button labels. |
| `background` | `#F8FAF9` | `#101312` | The page. |
| `surface` | `#FFFFFF` | `#191D1C` | Cards, sheets, inputs. |
| `cardBorder` | `#E6EAE8` | `#2A302E` | Hairline. |
| `pageBackdrop` | `#EDF1EF` | `#0A0C0B` | Gutters either side of the app column on a desktop window. |
| `onBrand` | `#FFFFFF` | `#FFFFFF` | The one token identical in both themes, because what it sits on (brand green, a photo scrim) is dark in both. |
| `textPrimary` | `#1A202C` | `#E8EBEA` | |
| `textMuted` | `#5A6169` | `#A2ABA6` | Secondary text a user actually reads. |
| `textSubtle` | `#767C81` | `#8A938D` | Small print only. |
| `agentBlue` / `agentBlueBg` | `#3E6DB5` / `#E7EFFA` | `#7FA8E0` / `#1B2534` | Seller type: agent. Also: official-data badge. |
| `dealerOrange` / `dealerOrangeBg` | `#B4671C` / `#FBEFE0` | `#E0A05A` / `#33261A` | Seller type: dealer. Also: community-data badge. |
| `errorRed` / `errorBg` | `#E5604D` / `#FCEBEB` | `#F08575` / `#33201E` | |
| `warnBg` / `warnText` | `#FBE7D4` / `#7A3E0A` | `#332819` / `#E5B07A` | |
| `starColor` | `#BA7517` | `#E0A94A` | |
| `mintAccent` | `#5DCAA5` | `#5DCAA5` | |

### The green is split by job — do not collapse it

There are three greens because no single one clears 4.5:1 in all three roles:

- White on `teal` measures **3.96:1** — below the 4.5 floor for a button label.
  So buttons and the app bar use `tealFill`, which measures **5.07:1**. Same hue
  (147.8°) and saturation, 6% less lightness, so it still reads as the same green.
- `teal` on white measures ~3.3:1 — fine for a **graphic** (3:1 floor), not for
  text. Green *ink* on the page is `tealText2` (6.74:1 light / 8.09:1 dark).

Treat these as three different tokens with three different jobs, never as
"light/medium/dark green".

### Contrast floors this system holds to

- Body and label text: **4.5:1** against whatever it sits on.
- Icons, borders, and other non-text graphics: **3:1**.
- `textSubtle` measures ~4.2:1 and is for incidental small print only. It was
  once `#9AA0A6` at 2.64:1 — a real shipped bug.

### One trap worth naming

A text button placed on the app bar inherits the framework default
`colorScheme.primary` — the brand green — on a `tealFill` background. That is
**1.2:1**: rendered, tappable, unreadable. App-bar text actions must use
`onBrand`. This shipped and a user caught it from a screenshot.

---

## 3. Type scale

The scale sets no font family — components inherit Heebo. Sizes in px, `B` = bold.

| step | size | use |
|---|---|---|
| `display` | 24 B | Hero figures, price on the detail page |
| `h1` | 22 B | |
| `h2` | 20 B | |
| `h3` | 18 B | |
| `title` | 16 B | Card headers, section titles, button labels |
| `subtitle` | 15 B | List-item names, sub-sections |
| `body` | 14 / line-height 1.35 | |
| `bodySm` | 13 / 1.35 | The workhorse inside cards |
| `caption` | 12.5 | Explanatory line under a heading (`textMuted`) |
| `captionBold` | 12.5 / 600 | |
| `micro` | 11.5 | Timestamps, counters, badge text (`textSubtle`) |
| `microBold` | 11.5 B | |
| `tiny` | 9.5 B | Map labels and other very dense spots. Use sparingly. |

Headings and body inherit the theme's ink. The muted family carries its colour
as part of its meaning — that is why it is a separate set.

---

## 4. Shape and spacing

**Radius** — xs `8` (chips, inline badges) · sm `12` (inner elements, banners,
small buttons) · md `14` (inputs, primary buttons) · lg `16` (cards, panels —
the default) · xl `20` (bottom sheets) · pill `999`.

**Spacing** — multiples of 4: xxs `2` · xs `4` · sm `8` · md `12` · lg `16` ·
xl `24` · xxl `32`. Pick the nearest step; do not invent numbers. Before this
scale existed the app had 14 different radii for the same idea.

**Breakpoints** — `620` car list becomes a grid · `720` a screen has room for
side-by-side content · `900` the app stops stretching and centres, with
`pageBackdrop` in the gutters.

**Tap targets: 48×48 minimum**, always.

---

## 5. The brand mark

**Drawn in code, not an image.** Exact geometry follows — please reproduce it
rather than redrawing by eye.

### Emblem — 140 × 150 composition

Three layers, centred:

1. **Shield**, 120 × 135, centred. Two paths in a 100 × 115 viewBox:
   - Outer, **stroked** (width 6, round joins), colour `#558B6E`:
     `M50 5 C75 5 95 18 95 28 L95 65 C95 92 65 108 50 112 C35 108 5 92 5 65 L5 28 C5 18 25 5 50 5 Z`
   - Inner, **filled** `#558B6E`:
     `M50 14 C70 14 87 25 87 33 L87 63 C87 85 62 98 50 102 C38 98 13 85 13 63 L13 33 C13 25 30 14 50 14 Z`
2. **Car photo** — a real front-view car image with the background removed,
   width 72, centred, offset **−6 on Y**. (Asset: `assets/layers/car.png`,
   uploaded alongside this brief. It is a photograph, not an illustration.)
3. **Check badge** — a 60 × 60 **white circle with a 3px `#558B6E` border**,
   pinned to `right: 0, bottom: 2`. Inside it, a 34 × 34 checkmark. The white
   badge exists so the check never blends into the shield.

**Checkmark path** (60 × 60 viewBox, stroke width 10, round cap and join):
`M12 30 L26 44 L48 16`

Self-contained SVG of the emblem, minus the car layer:

```svg
<svg viewBox="0 0 140 150" xmlns="http://www.w3.org/2000/svg">
  <g transform="translate(10 7.5) scale(1.2 1.173913)">
    <path d="M50 5 C75 5 95 18 95 28 L95 65 C95 92 65 108 50 112 C35 108 5 92 5 65 L5 28 C5 18 25 5 50 5 Z"
          fill="none" stroke="#558B6E" stroke-width="6" stroke-linejoin="round"/>
    <path d="M50 14 C70 14 87 25 87 33 L87 63 C87 85 62 98 50 102 C38 98 13 85 13 63 L13 33 C13 25 30 14 50 14 Z"
          fill="#558B6E"/>
  </g>
  <!-- car.png goes here: width 72, centred, centre at y=69 -->
  <circle cx="110" cy="118" r="28.5" fill="#FFFFFF" stroke="#558B6E" stroke-width="3"/>
  <g transform="translate(93 101) scale(0.566667)">
    <path d="M12 30 L26 44 L48 16" fill="none" stroke="#558B6E" stroke-width="10"
          stroke-linecap="round" stroke-linejoin="round"/>
  </g>
</svg>
```

### Wordmark — the check finishes the name

The type reads **"Bonnet"** and the checkmark plays the word "Check". Name and
mark are one idea, not two things side by side.

- "Bonnet" in **Poppins 700**, letter-spacing `0.5`, line-height `1`, ink
  `textPrimary`.
- The check follows it at **cap height = fontSize × 0.86**, width = cap height ×
  1.05, colour `teal`. (0.86, not the 0.72 a letterform would take, because it
  stands in for five letters.)
- Optical spacing: left padding `fontSize × 0.06`, bottom `fontSize × 0.04`.
  Baseline-aligned to the type.
- **Pinned LTR** — it is a Latin mark inside an RTL app and must never flip.

Entrance animation (splash): "Bonnet" travels in from the left and the check
from the right, meeting in the middle; then the check's stroke draws itself on.
Each half travels `fontSize × 2.2`. The pieces translate rather than re-layout,
so the mark never reflows while assembling.

The launcher icon is **emblem only, no text**.

---

## 6. Components to build

For each: light and dark, and the RTL layout.

### Surfaces
- **Card** — `surface`, 1px `cardBorder` hairline, radius `lg`, padding `lg`.
  Variants: default, elevated (shadow `rgba(0,0,0,.12)` blur 16, y-offset 4),
  selected (2px `teal` border), tappable. This one decoration was hand-written
  24 times across 20 files before it was a component.
- **Section card** — the card plus a standard header: `teal` icon at 18, bold
  `subtitle` title, optional trailing element, optional caption line beneath.

### Trust and provenance — the components that carry the product's promise
- **Data-source badge** — two states, and they must stay **two different hues,
  never two shades of the brand green**, so the distinction survives a glance:
  - *Official*: `agentBlueBg` fill, `agentBlue` ink, bank icon,
    `מידע רשמי · משרד התחבורה`
  - *Community*: `dealerOrangeBg` fill, `dealerOrange` ink, people icon, 1px
    `cardBorder`, `מידע קהילתי · דיווחי משתמשים`
  - 11.5px bold, radius `xs`, padding 8×3. The label must shrink gracefully —
    it now also appears inside a narrow table column.
- **Seller-type badge** — private (`teal`, `בעלים פרטי`) / agent (`agentBlue`,
  `סוכן`) / dealer (`dealerOrange`, `סוחר`). Equal visual weight. None may look
  like a warning.
- **Liability notice** — `background` fill, `cardBorder` border, radius `sm`,
  a small `textSubtle` gavel icon and `micro` text. Sits at the foot of any
  screen that mixes official records with user reports.

### Listing
- **Car card** — photo strip 170px tall; below it the title (`title`, one line,
  ellipsis), the price on **its own line** (`title`, `tealText2`, LTR-pinned),
  and a meta line (`11.5`, `textMuted`) reading
  `92,000 ק"מ · יד 2 · תל אביב · 2019`.
  On the photo: seller badge bottom-start, a 40px circular save button
  top-start, review chip bottom-end. The badge and the chip must never share a
  corner — they overlapped by 17px on a 320px phone once.
  Save button: unsaved is a `rgba(0,0,0,.40)` disc, saved fills with `tealFill`;
  the check inside stays `onBrand` in both, so only the disc changes.
  Selection variant: a tick circle replaces the save button and the card takes a
  2px `teal` border.
  The card's height is **computed by measuring its text**, not estimated — a
  grid cell has to be sized before the card exists.
- **Saved mark** — the brand check alone. (It used to be a heart; the heart was
  dropped so the check is the app's one affirmative symbol.)

### Navigation and actions
- **Bottom nav** — a floating pill, five tabs, RTL so the first is rightmost:
  `בית · שמורים · דלק · צ'אטים · פרופיל`.
- **App bar** — `tealFill` background, `onBrand` foreground, centred title,
  no elevation.
- **App-bar text action** — `onBrand` ink, 48×48 minimum. See §2's trap.
- **Buttons** — filled (`tealFill` / `onBrand`, radius `sm`, min 64×48, label
  15 bold) · outlined (`tealText2` label, `teal` border, min 64×46) · primary
  full-width (radius 14, min height 52, label 16 bold) · text.
  Minimum size must constrain **height only** — a width-infinite minimum
  stretches dialog actions until they overflow.
- **Skeleton loader** — replaces spinners on list screens.
- **Guest prompt** — icon, title, body, action; shown where an action needs a
  sign-in.
- **Photo chip / photo icon button** — black scrim plus `onBrand`, because a
  photograph is not a themed surface and no theme token is legible on all photos.

### Comparison table (newest screen — worth a card of its own)
Two or three shortlisted cars side by side. A pinned header of photo + name sits
outside a vertically scrolling body; the whole table scrolls horizontally as one
unit. Row label column 76px, cells at least 96px, zebra striping.

Cell states, in this precedence:
1. **Warning** (`errorBg` fill, `errorRed` ink, bold) — an expired licence, a
   recorded structural change, an odometer below the last official reading.
2. **Row advantage** (`tealLight` fill, `tealText` ink, bold) — cheapest, fewest
   km, newest, fewest recalls.
3. **Reassuring** (`tealText2` ink, no fill).
4. Neutral.

A warning outranks an advantage deliberately: the cheapest of three cars may be
the one with the accident record, and a green "best price" pill on that cell
would bury what matters.

**The table marks one row at a time and never declares a winner.** No score, no
total, no recommendation. Weighing price against accident history is the buyer's
judgement, and a single number pretending to do it would be a claim the product
cannot stand behind. Rows that are not a competition — seller type, engine
capacity, colour — carry no mark at all.

---

## 7. Rules any new component has to follow

1. Official records and user-submitted content must never be styled the same.
2. Never imply certainty. Copy says what was checked and what was not.
3. Never rank seller types.
4. Missing data reads as **"not reported"** (an em dash), never as zero, and
   never as an empty space that looks like nothing was checked. If a whole
   section has no data, say so in words — a section that silently disappears
   makes "we checked and found nothing" look identical to "we never checked".
5. Both themes, always. Dark is not an afterthought here; it is a switch users
   actually use.
6. **No real Israeli licence plate anywhere** — in a mockup, a screenshot or a
   sample. Those are real registered vehicles and a privacy problem. Use
   obviously-fake plates or none.

---

## 8. What I would like back

Component cards covering §6, each in light and dark, laid out RTL, using the
tokens in §2–4 by name. Foundations first (colour, type, spacing, the brand
mark), then the components.

Where a component below could be better, say so and show the alternative — the
existing design is measured, not sacred. The one part that is fixed is §7.
