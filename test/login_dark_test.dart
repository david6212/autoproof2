import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:otov/core/theme/app_palette.dart';

/// The Apple button was a hard-coded `#111111`. That is a deliberate brand
/// colour on a white page and an invisible rectangle on a dark one — it sat on
/// `#101312` at a contrast ratio of about 1.01.
///
/// Nothing in the suite could catch that, because it is not a palette token:
/// `palette_test` only knows about colours that live in [AppPalette]. This
/// pins the rule the fix relies on instead — that any surface painted onto the
/// page has to be distinguishable from it.
void main() {
  double ratio(Color a, Color b) {
    final (x, y) = (a.computeLuminance(), b.computeLuminance());
    final (hi, lo) = x > y ? (x, y) : (y, x);
    return (hi + 0.05) / (lo + 0.05);
  }

  const appleBlack = Color(0xFF111111);

  test('the old hard-coded Apple black really was invisible on dark', () {
    // Documents the bug, so nobody "simplifies" the fix back out.
    expect(ratio(appleBlack, AppPalette.dark.background), lessThan(1.1));
  });

  test('the Apple button separates from the page in both themes', () {
    // What the screen now paints: black on light, white on dark.
    for (final (palette, bg, fg) in [
      (AppPalette.light, appleBlack, AppPalette.light.onBrand),
      (AppPalette.dark, AppPalette.dark.onBrand, appleBlack),
    ]) {
      expect(ratio(bg, palette.background), greaterThan(3.0),
          reason: 'button surface must separate from the page');
      expect(ratio(fg, bg), greaterThan(4.5),
          reason: 'label must be readable on the button');
    }
  });
}
