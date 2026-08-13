import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Type scale for BonnetCheck.
///
/// The app had grown 20 different `fontSize` values (12 and 12.5, 13 and 13.5,
/// 15 and 15.5 …) with no system. These are the steps that replace them —
/// reach for the nearest one instead of typing a raw size.
///
/// The font family is deliberately not set: `Text` merges these with the
/// ambient [DefaultTextStyle], so Heebo from the app theme still applies.
///
/// **Nor is the colour.** These used to bake in [AppColors] values, which
/// froze them to the light theme. The headings and body sizes now inherit the
/// theme's text colour, so they follow light and dark for free. The quieter
/// greys can't inherit — they are deliberately *not* the primary colour — so
/// they live on [AppTextOf] and are reached through `context.text`.
class AppText {
  AppText._();

  // ---- Headings — colour inherited from the theme ----

  /// Big numbers and hero figures (price, splash).
  static const display = TextStyle(fontSize: 24, fontWeight: FontWeight.bold);

  static const h1 = TextStyle(fontSize: 22, fontWeight: FontWeight.bold);

  static const h2 = TextStyle(fontSize: 20, fontWeight: FontWeight.bold);

  static const h3 = TextStyle(fontSize: 18, fontWeight: FontWeight.bold);

  /// Card headers, section titles, button labels.
  static const title = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);

  /// Slightly smaller header — list-item names, sub-sections.
  static const subtitle = TextStyle(fontSize: 15, fontWeight: FontWeight.bold);

  // ---- Body — colour inherited from the theme ----

  static const body = TextStyle(fontSize: 14, height: 1.35);

  /// The workhorse size for descriptive text inside cards.
  static const bodySm = TextStyle(fontSize: 13, height: 1.35);

  // ---- Shapes for the muted family; colour applied by [AppTextOf] ----

  static const _body = TextStyle(fontSize: 14, height: 1.35);
  static const _bodySm = TextStyle(fontSize: 13, height: 1.35);
  static const _caption = TextStyle(fontSize: 12.5);
  static const _captionBold =
      TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600);
  static const _micro = TextStyle(fontSize: 11.5);
  static const _microBold =
      TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold);
  static const _tiny = TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold);
}

/// The text styles whose colour is part of their meaning. Reached through
/// `context.text` so they follow the active theme.
class AppTextOf {
  const AppTextOf(this._p);

  final AppPalette _p;

  TextStyle get bodyMuted => AppText._body.copyWith(color: _p.textMuted);

  TextStyle get bodySmMuted => AppText._bodySm.copyWith(color: _p.textMuted);

  /// Explanatory lines under a heading.
  TextStyle get caption => AppText._caption.copyWith(color: _p.textMuted);

  TextStyle get captionBold =>
      AppText._captionBold.copyWith(color: _p.textMuted);

  TextStyle get captionSubtle =>
      AppText._caption.copyWith(color: _p.textSubtle);

  /// Timestamps, counters, badge text.
  TextStyle get micro => AppText._micro.copyWith(color: _p.textSubtle);

  TextStyle get microBold => AppText._microBold.copyWith(color: _p.textSubtle);

  /// Map labels and other very dense spots — use sparingly.
  TextStyle get tiny => AppText._tiny.copyWith(color: _p.tealText);
}

/// `context.text.caption` — the theme-aware half of the type scale.
extension AppTextContext on BuildContext {
  AppTextOf get text => AppTextOf(colors);
}
