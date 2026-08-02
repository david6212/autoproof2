// A half-converted dark theme is worse than none — dark text on a dark card
// is unreadable, and no widget test notices. These assert the properties that
// make the dark palette actually dark, so a token added to one theme and
// forgotten in the other fails here rather than on someone's phone.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:otov/core/theme/app_palette.dart';

const light = AppPalette.light;
const dark = AppPalette.dark;

/// Surfaces the app's own content sits on. These must invert.
Map<String, (Color, Color)> get surfaces => {
      'background': (light.background, dark.background),
      'surface': (light.surface, dark.surface),
      'tealLight': (light.tealLight, dark.tealLight),
      'pageBackdrop': (light.pageBackdrop, dark.pageBackdrop),
      'agentBlueBg': (light.agentBlueBg, dark.agentBlueBg),
      'dealerOrangeBg': (light.dealerOrangeBg, dark.dealerOrangeBg),
      'errorBg': (light.errorBg, dark.errorBg),
      'warnBg': (light.warnBg, dark.warnBg),
    };

/// Text and icons. These must invert the other way.
Map<String, (Color, Color)> get inks => {
      'textPrimary': (light.textPrimary, dark.textPrimary),
      'textMuted': (light.textMuted, dark.textMuted),
      'textSubtle': (light.textSubtle, dark.textSubtle),
      'tealText': (light.tealText, dark.tealText),
      'tealText2': (light.tealText2, dark.tealText2),
      'warnText': (light.warnText, dark.warnText),
    };

void main() {
  group('dark palette', () {
    test('every surface gets darker', () {
      surfaces.forEach((name, pair) {
        final (l, d) = pair;
        expect(d.computeLuminance(), lessThan(l.computeLuminance()),
            reason: '$name is not darker in the dark theme');
      });
    });

    // Absolute luminance is the wrong question for ink — the quietest grey
    // is mid-toned in both themes. What has to hold is that it contrasts with
    // whatever it is printed on, in the right direction.
    test('every ink reads light against a dark surface', () {
      inks.forEach((name, pair) {
        final (l, d) = pair;
        expect(l.computeLuminance(),
            lessThan(light.surface.computeLuminance()),
            reason: '$name should be darker than the light surface');
        expect(d.computeLuminance(), greaterThan(dark.surface.computeLuminance()),
            reason: '$name should be lighter than the dark surface');
      });
    });

    test('even the quietest ink clears 3:1 on its surface', () {
      double ratio(Color a, Color b) {
        final (x, y) = (a.computeLuminance(), b.computeLuminance());
        final (hi, lo) = x > y ? (x, y) : (y, x);
        return (hi + 0.05) / (lo + 0.05);
      }

      // 3:1 is the floor for the small, secondary text these are used for.
      expect(ratio(dark.textSubtle, dark.surface), greaterThan(3.0));
      expect(ratio(dark.tealText, dark.tealLight), greaterThan(3.0));
      expect(ratio(dark.textMuted, dark.surface), greaterThan(4.5));
    });

    test('the light theme’s subtle grey is the one that misses 3:1', () {
      // Not introduced by the dark theme — #9AA0A6 on white has always
      // measured about 2.64:1, below the 3:1 floor for small text. Pinned
      // rather than quietly corrected, because changing it is a brand
      // decision. Darkening textSubtle to roughly #767C81 would clear it.
      double ratio(Color a, Color b) {
        final (x, y) = (a.computeLuminance(), b.computeLuminance());
        final (hi, lo) = x > y ? (x, y) : (y, x);
        return (hi + 0.05) / (lo + 0.05);
      }

      expect(ratio(light.textSubtle, light.surface), closeTo(2.64, 0.05));
    });

    test('body text stays readable on the card it sits on', () {
      // Not a full WCAG check — just that the two are far enough apart that
      // the pairing cannot have been left inverted.
      final gap = (dark.textPrimary.computeLuminance() -
              dark.surface.computeLuminance())
          .abs();
      expect(gap, greaterThan(0.5));
    });

    test('muted text is quieter than primary, not brighter', () {
      expect(dark.textMuted.computeLuminance(),
          lessThan(dark.textPrimary.computeLuminance()));
      expect(dark.textSubtle.computeLuminance(),
          lessThan(dark.textMuted.computeLuminance()));
    });

    test('a card is distinguishable from the page behind it', () {
      expect(dark.surface, isNot(dark.background));
      expect(dark.cardBorder, isNot(dark.surface));
    });

    test('the brand green and white-on-brand are shared, on purpose', () {
      // The emblem, buttons and header must look like the same product in
      // both themes, and what onBrand sits on is dark either way.
      expect(dark.teal, light.teal);
      expect(dark.onBrand, light.onBrand);
    });

    test('lerp lands on the endpoints', () {
      expect(light.lerp(dark, 0).surface, light.surface);
      expect(light.lerp(dark, 1).surface, dark.surface);
    });
  });
}
