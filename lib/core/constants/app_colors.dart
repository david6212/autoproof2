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
  static const white = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFE6EAE8);

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
