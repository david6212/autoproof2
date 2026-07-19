import 'package:flutter/material.dart';

/// AutoProof brand colors. Never hardcode hex values in widgets — always
/// reference AppColors.X.
class AppColors {
  AppColors._();

  // Primary
  static const teal = Color(0xFF0F6E56);
  static const tealDark = Color(0xFF0B3D33);
  static const tealLight = Color(0xFFE1F5EE);
  static const tealText = Color(0xFF04342C);
  static const tealText2 = Color(0xFF085041);

  // Backgrounds
  static const background = Color(0xFFF4F3EE);
  static const white = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFE2E0D8);

  // Text
  static const textPrimary = Color(0xFF15191D);
  static const textMuted = Color(0xFF5F5E5A);
  static const textSubtle = Color(0xFF9C9B96);

  // Semantic
  static const errorRed = Color(0xFFE5604D);
  static const errorBg = Color(0xFFFCEBEB);
  static const warnBg = Color(0xFFFBE7D4);
  static const warnText = Color(0xFF7A3E0A);
  static const starColor = Color(0xFFBA7517);
  static const mintAccent = Color(0xFF5DCAA5);
}
