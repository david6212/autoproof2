import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Type scale for KLARO.
///
/// The app had grown 20 different `fontSize` values (12 and 12.5, 13 and 13.5,
/// 15 and 15.5 …) with no system. These are the steps that replace them —
/// reach for the nearest one instead of typing a raw size.
///
/// The font family is deliberately not set: `Text` merges these with the
/// ambient [DefaultTextStyle], so Heebo from the app theme still applies.
class AppText {
  AppText._();

  // ---- Headings ----

  /// Big numbers and hero figures (price, splash).
  static const display = TextStyle(
      fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary);

  static const h1 = TextStyle(
      fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary);

  static const h2 = TextStyle(
      fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary);

  static const h3 = TextStyle(
      fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary);

  /// Card headers, section titles, button labels.
  static const title = TextStyle(
      fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary);

  /// Slightly smaller header — list-item names, sub-sections.
  static const subtitle = TextStyle(
      fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary);

  // ---- Body ----

  static const body = TextStyle(
      fontSize: 14, height: 1.35, color: AppColors.textPrimary);

  static const bodyMuted = TextStyle(
      fontSize: 14, height: 1.35, color: AppColors.textMuted);

  /// The workhorse size for descriptive text inside cards.
  static const bodySm = TextStyle(
      fontSize: 13, height: 1.35, color: AppColors.textPrimary);

  static const bodySmMuted = TextStyle(
      fontSize: 13, height: 1.35, color: AppColors.textMuted);

  // ---- Small print ----

  /// Explanatory lines under a heading.
  static const caption =
      TextStyle(fontSize: 12.5, color: AppColors.textMuted);

  static const captionBold = TextStyle(
      fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textMuted);

  static const captionSubtle =
      TextStyle(fontSize: 12.5, color: AppColors.textSubtle);

  /// Timestamps, counters, badge text.
  static const micro =
      TextStyle(fontSize: 11.5, color: AppColors.textSubtle);

  static const microBold = TextStyle(
      fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textSubtle);

  /// Map labels and other very dense spots — use sparingly.
  static const tiny = TextStyle(
      fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.tealText);
}
