import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/core/theme/app_palette.dart';

/// The app has two greens on purpose and they are not interchangeable:
/// `teal` identifies the product (emblem, icons, borders) and `tealFill` is the
/// colour you put white ON.
///
/// The failure mode is one-directional and quiet. Using `tealFill` where
/// `teal` belongs looks slightly heavy. Using **`teal` where `tealFill`
/// belongs puts white text at 3.96:1** — legible enough to pass a glance,
/// under the floor, and it has now happened three separate times: a confirm
/// button in my-listing, the filter-count badge on Home, and the app-bar text
/// action.
///
/// A grep cannot tell an icon from a fill, so this states the numbers the two
/// tokens have to keep. A future colour change that breaks the distinction
/// fails here.
void main() {
  double ratio(Color a, Color b) {
    final (x, y) = (a.computeLuminance(), b.computeLuminance());
    final (hi, lo) = x > y ? (x, y) : (y, x);
    return (hi + 0.05) / (lo + 0.05);
  }

  test('white on the identity green is NOT good enough for text', () {
    // If this ever passes 4.5, the two tokens have converged and the rule
    // above stops being true — which is worth knowing deliberately, not by
    // discovering the tokens are now interchangeable.
    for (final p in [AppPalette.light, AppPalette.dark]) {
      expect(ratio(p.onBrand, p.teal), lessThan(4.5),
          reason: 'teal is an identity colour, not a fill for white text');
    }
  });

  test('white on the fill green clears the floor with room', () {
    for (final p in [AppPalette.light, AppPalette.dark]) {
      expect(ratio(p.onBrand, p.tealFill), greaterThan(6.0));
    }
  });

  test('the identity green still works as a graphic', () {
    // 3:1 is the floor for a non-text mark. `teal` has to keep clearing it on
    // the page, or the emblem and every outline icon go with it.
    expect(ratio(AppPalette.light.teal, AppPalette.light.background),
        greaterThan(3.0));
    expect(ratio(AppPalette.dark.teal, AppPalette.dark.background),
        greaterThan(3.0));
  });

  test('green ink is a third token, and clears text contrast on a card', () {
    // The one that is neither: readable as TEXT on a surface, in both themes.
    // This is what a label, a link or a selected tab takes.
    for (final p in [AppPalette.light, AppPalette.dark]) {
      expect(ratio(p.tealText2, p.surface), greaterThan(4.5));
    }
  });

  test('the three greens are genuinely three', () {
    for (final p in [AppPalette.light, AppPalette.dark]) {
      final greens = {p.teal, p.tealFill, p.tealText2};
      expect(greens, hasLength(3),
          reason: 'identity, fill and ink must stay distinct');
    }
  });
}
