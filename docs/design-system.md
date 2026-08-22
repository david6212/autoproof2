# BonnetCheck — design system

Extracted from the running code, not from a style guide written alongside it.
Every value below is the one the app actually uses; the file paths say where.

Upload this together with the screenshots in `docs/design-system-shots/` when
setting up a design system in Claude Design — a finished screen tells it more
about the brand's feel than a palette does.

---

## 1. What the product is

BonnetCheck is a Hebrew, right-to-left marketplace for second-hand cars in
Israel that cross-references every listing against the Ministry of Transport's
public vehicle registry.

This matters to the design system because the product's whole promise is
**"we tell you exactly what we checked, and exactly what we didn't."** Anything
that looks more certain than the data behind it is off-brand, however good it
looks. That single rule decides more visual questions here than the palette
does — it is why findings sit at the top of a listing, why a section that could
not be checked says so, and why nothing counts down or pressures.

- Language: Hebrew, RTL. Code and comments: English.
- Platforms: Android, iOS, web (the same Flutter build).

---

## 2. The mark

Source of truth: `lib/presentation/widgets/brand_logo.dart`. Read the painters
before drawing it — every past attempt to reproduce it from memory got it wrong.

**Wordmark.** The type reads **"Bonnet"** and a checkmark finishes the name —
the check *is* the word "Check", not decoration beside it. Set in Poppins Bold.
The check's cap-height factor is **0.86** of the font size (it stands in for
five letters; the previous mark's tick replaced one letter and used 0.72).
Entrance animation: "Bonnet" enters from one side, the check from the other,
and they meet.

**Emblem.** A stroked outer shield (stroke width 6, viewBox 100×115) + a filled
inner shield + a real photograph of a car (`assets/layers/car.png`, 72 wide,
offset y −6) + a checkmark on a **white circular badge with a green border** at
the bottom-right. The badge exists so the check never blends into the shield.

**Never:** re-letter the wordmark, redraw the shield as a rounded rectangle,
replace the car photograph with an icon, or put the check anywhere but the
end of the word.

---

## 3. Colour

Source of truth: `lib/core/constants/app_colors.dart` (raw light values) and
`lib/core/theme/app_palette.dart` (both themes). In app code colours are read
from the theme — `context.colors.x` — never from the raw class.

### The one rule that is not obvious

**The brand green is split by job.** `teal` `#558B6E` is the identity colour and
belongs to the mark. It is *not* a fill behind white text: white on `#558B6E`
measures **3.96:1**, under the 4.5 floor. So:

| Token | Light | Job |
|---|---|---|
| `teal` | `#558B6E` | Identity only — the emblem, the wordmark |
| `tealFill` | `#1E6B45` | Any surface that carries white text: primary buttons, the FAB, filled progress |
| `tealText` | `#294539` | Green ink on a pale green wash |
| `tealText2` | `#40634F` | The lighter green ink |
| `tealDark` | `#3C614C` | Dark green panels (the registry card header) |
| `tealLight` | `#E7EFEA` | Pale green wash behind icons and banners |
| `headerTint` | `#EAF3ED` | The faint tint behind a header |

### Surfaces and text

| Token | Light | Dark |
|---|---|---|
| `background` | `#F8FAF9` | `#101312` |
| `surface` | `#FFFFFF` | `#191D1C` |
| `cardBorder` | `#E6EAE8` | `#2A302E` |
| `pageBackdrop` | `#EDF1EF` | `#0A0C0B` |
| `onBrand` | `#FFFFFF` | `#FFFFFF` |
| `textPrimary` | `#1A202C` | `#E8EBEA` |
| `textMuted` | `#5A6169` | `#A2ABA6` |
| `textSubtle` | `#767C81` | `#8A938D` |

`textSubtle` is `#767C81` and not the lighter grey it started as — the original
measured 2.64:1 on white, under the 3:1 floor for incidental text.

### Semantic accents

| Token | Light | Dark | Meaning |
|---|---|---|---|
| `agentBlue` / `agentBlueBg` | `#3E6DB5` / `#E7EFFA` | `#7FA8E0` / `#1B2534` | Seller classified as an agent |
| `dealerOrange` / `dealerOrangeBg` | `#B4671C` / `#FBEFE0` | `#E0A05A` / `#33261A` | Seller classified as a dealer |
| `errorRed` / `errorBg` | `#E5604D` / `#FCEBEB` | `#F08575` / `#33201E` | A finding that contradicts an official record |
| `warnText` / `warnBg` | `#7A3E0A` / `#FBE7D4` | `#E5B07A` / `#332819` | Worth asking about before money changes hands |
| `starColor` | `#BA7517` | `#E0A94A` | Ratings |
| `mintAccent` | `#5DCAA5` | `#5DCAA5` | Sparingly, for the "documented" badge |

### Dark mode

Two rules held throughout: the brand green does **not** change, so the emblem,
the buttons and the header look like the same product in both themes; and every
pale wash becomes a deep wash of the same hue with its text lightened to match.
Dark mode is a switch, not a three-way picker.

---

## 4. Type

Source of truth: `lib/core/theme/app_text.dart`. **Heebo** throughout (Hebrew
first), **Poppins** for the wordmark only. Eleven sizes, and adding a twelfth
should feel like a decision:

| Style | Size | Weight |
|---|---|---|
| `display` | 24 | Bold |
| `h1` | 22 | Bold |
| `h2` | 20 | Bold |
| `h3` | 18 | Bold — every step title and section head |
| `title` | 16 | Bold |
| `subtitle` | 15 | Bold |
| `body` | 14 | Regular, line-height 1.35 |
| `bodySm` | 13 | Regular, 1.35 |
| `caption` | 12.5 | Regular (`captionBold` w600) |
| `micro` | 11.5 | Regular (`microBold` bold) |
| `tiny` | 9.5 | Bold |

---

## 5. Shape and spacing

Source of truth: `lib/core/theme/app_dimens.dart`. Before this existed the app
had fourteen different corner radii. Pick the nearest step; do not invent one.

**Radius:** `xs 8` chips and inline badges · `sm 12` inner tiles and banners ·
`md 14` inputs and primary buttons · `lg 16` cards, sheets, panels (the default)
· `xl 20` bottom sheets · `pill 999` pills and avatars.

**Spacing** — multiples of 4: `xxs 2 · xs 4 · sm 8 · md 12 · lg 16 · xl 24 ·
xxl 32`.

---

## 6. Components

| Component | Where | Notes |
|---|---|---|
| `AppCard` | `widgets/app_card.dart` | The container. Carries surface, radius, border colour and width. Hand-rolled `Container` cards were removed — three deliberate exceptions remain, each commented. |
| `PrimaryButton` | `widgets/primary_button_widget.dart` | Full-width, `tealFill`, white label, radius `md`. Its own loading state. |
| `PublishFab` | `widgets/publish_fab.dart` | Extended FAB, `tealFill` + `onBrand`, car icon, labelled. A bare icon reads as "my cars" on a screen of cars. |
| `SpecTile` / `SpecTileGrid` | `widgets/spec_tile.dart` | Pairs tiles, equalises row heights, refuses to stretch a lone tile. |
| `CollapsibleSection` | `widgets/common/collapsible_section.dart` | Folding, never hiding: a collapsed section always shows a **summary** ("12 שדות"), and the reader's choice is remembered. |
| `ActiveWarningsSection` | `widgets/car/` | Findings at the top of a listing, two severities. Renders nothing — and takes no vertical room — when there is nothing to report. |
| `PlateText` | `widgets/plate_text.dart` | The only widget allowed to draw a plate. Starred out by default; the owner alone can tap to reveal. |
| `AppNavBar` | `widgets/app_nav_bar.dart` | Flat bottom bar, every tab named. Five slots is the ceiling. |
| `StepProgress` | `widgets/step_progress_widget.dart` | One per journey. Two progress bars in one flow is a bug, not a layout. |
| `Skeleton` | | Skeleton loaders, not spinners, wherever the shape of the result is known. |

---

## 7. Layout

- **RTL first.** Back arrows use `Icons.arrow_back` — both arrow glyphs carry
  `matchTextDirection: true`, so Flutter mirrors them; `arrow_forward` points
  the wrong way in Hebrew. Five screens got this wrong before a scan caught it.
- **Desktop:** a centred column over `pageBackdrop`, so a wide window reads as
  a page rather than a stretched phone.
- Photos are responsive — `width × 0.72`, clamped 240–360, capped at half the
  viewport — rather than a fixed height that letterboxes wide images.
- Tap targets: 48px.

---

## 8. Voice — part of the design, not a separate document

Rules 1 and 3 are enforced by tests that scan the whole source tree
(`test/ethics_test.dart`, `test/journey_official_link_test.dart`), because they
are the brand rather than a preference:

1. **Never state a claim the code does not perform.** If a sentence cannot be
   traced to behaviour, it does not ship.
2. **A gap is a gap.** When a government dataset does not answer, say so.
   Rendering an absence as an all-clear is the one unforgivable error here.
3. **No dark patterns.** No countdowns, no "N people are viewing this", no
   shaming decline buttons, no loss-aversion framing.
4. **Count what was done, not what is missing.** "רשומה אחת מתוך 3" — not
   "עוד 2 חסרות". Same two numbers; the first is the one people act on.
5. **Commercial links and official links never look alike.** Official services
   name their source on the card; commercial links live in their own component.
