import 'package:flutter/material.dart';

/// OtoV brand colors. Never hardcode hex values in widgets — always
/// reference AppColors.X.
class AppColors {
  AppColors._();

  // Primary — matched to the splash screen palette (sage green #558B6E).
  static const teal = Color(0xFF558B6E);
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
  static const textSubtle = Color(0xFF9AA0A6);

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
