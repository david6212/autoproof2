import 'package:flutter/material.dart';

/// BonnetCheck brand colors. Never hardcode hex values in widgets — always
/// reference AppColors.X.
class AppColors {
  AppColors._();

  // Primary — matched to the splash screen palette (sage green #558B6E).
  static const teal = Color(0xFF558B6E);

  /// The same green, 6% darker in lightness, for use **under white text**.
  ///
  /// White on [teal] measures 3.96:1 — below the 4.5 floor for a button label
  /// at 15–16px bold. This measures 5.07:1. Hue (147.8°) and saturation are
  /// identical, so it reads as the same green; only buttons and app bars use
  /// it. The emblem and the wordmark's check stay on [teal].
  static const tealFill = Color(0xFF4A785F);
  static const tealDark = Color(0xFF3C614C);
  static const tealLight = Color(0xFFE7EFEA);
  static const tealText = Color(0xFF294539);
  static const tealText2 = Color(0xFF40634F);

  // Backgrounds — cool near-white like the splash background.
  static const background = Color(0xFFF8FAF9);
  static const cardBorder = Color(0xFFE6EAE8);

  /// Cards, sheets, inputs — anything the page's content sits on.
  /// Distinct from [onBrand]: this one flips in a dark theme.
  static const surface = Color(0xFFFFFFFF);

  /// Foreground on a brand-coloured or photographic background — the teal
  /// header, a filled button's label, text over a photo scrim. Stays white in
  /// every theme, because what it sits on stays dark in every theme.
  static const onBrand = Color(0xFFFFFFFF);

  /// Fills the gutters either side of the app on a desktop window. A shade
  /// deeper than [background] so the app column reads as the page.
  static const pageBackdrop = Color(0xFFEDF1EF);

  // Text — splash ink.
  static const textPrimary = Color(0xFF1A202C);
  static const textMuted = Color(0xFF5A6169);
  /// Darkened from #9AA0A6, which measured only 2.64:1 on white — under the
  /// 3:1 floor for the small print this is used for. Now ~4.2:1.
  static const textSubtle = Color(0xFF767C81);

  // Seller-type accents (private uses the brand teal)
  static const agentBlue = Color(0xFF3E6DB5);
  static const agentBlueBg = Color(0xFFE7EFFA);
  static const dealerOrange = Color(0xFFB4671C);
  static const dealerOrangeBg = Color(0xFFFBEFE0);

  // Semantic
  static const errorRed = Color(0xFFE5604D);
  static const errorBg = Color(0xFFFCEBEB);
  static const warnBg = Color(0xFFFBE7D4);
  static const warnText = Color(0xFF7A3E0A);
  static const starColor = Color(0xFFBA7517);
  static const mintAccent = Color(0xFF5DCAA5);
}
