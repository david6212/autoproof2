import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Every colour in the app, resolved per theme.
///
/// [AppColors] still holds the raw light values — this is the layer that
/// decides which set is in force. Widgets read `context.colors.x` rather than
/// `AppColors.x`, because a `static const` is fixed at compile time and can
/// never answer "which theme is this".
///
/// Adding a token means adding it in three places: the field, [light] and
/// [dark]. That is deliberate — a token with no dark value is a bug waiting
/// for a user with dark mode on.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.teal,
    required this.tealFill,
    required this.tealDark,
    required this.tealLight,
    required this.headerTint,
    required this.tealText,
    required this.tealText2,
    required this.background,
    required this.surface,
    required this.cardBorder,
    required this.pageBackdrop,
    required this.onBrand,
    required this.textPrimary,
    required this.textMuted,
    required this.textSubtle,
    required this.agentBlue,
    required this.agentBlueBg,
    required this.dealerOrange,
    required this.dealerOrangeBg,
    required this.errorRed,
    required this.errorBg,
    required this.warnBg,
    required this.warnText,
    required this.starColor,
    required this.mintAccent,
  });

  final Color teal;

  /// The brand green **as a fill under white text** — filled buttons, the app
  /// bar, map pins. Deeper than [teal], because white on `#558B6E` is only
  /// 3.96:1 and the floor for a button label is 4.5. This is **6.47**.
  ///
  /// It is a separate token rather than a darker [teal] because the two do
  /// different jobs: [teal] identifies the product (the emblem, the check in
  /// the wordmark, icons, borders) and must not drift, while this one only has
  /// to carry white legibly.
  final Color tealFill;

  final Color tealDark;
  final Color tealLight;

  /// The pale wash behind the top of a screen — the home header, an icon well.
  /// Distinct from [tealLight], which tints a component; this tints a REGION,
  /// and is deliberately fainter so a chip sitting on it still reads as a chip.
  final Color headerTint;
  final Color tealText;
  final Color tealText2;
  final Color background;
  final Color surface;
  final Color cardBorder;
  final Color pageBackdrop;

  /// White on the brand colour, on black, or over a photo scrim. The one
  /// token that is identical in both themes, because what it sits on is.
  final Color onBrand;

  final Color textPrimary;
  final Color textMuted;
  final Color textSubtle;
  final Color agentBlue;
  final Color agentBlueBg;
  final Color dealerOrange;
  final Color dealerOrangeBg;
  final Color errorRed;
  final Color errorBg;
  final Color warnBg;
  final Color warnText;
  final Color starColor;
  final Color mintAccent;

  static const light = AppPalette(
    teal: AppColors.teal,
    tealFill: AppColors.tealFill,
    tealDark: AppColors.tealDark,
    tealLight: AppColors.tealLight,
    headerTint: AppColors.headerTint,
    tealText: AppColors.tealText,
    tealText2: AppColors.tealText2,
    background: AppColors.background,
    surface: AppColors.surface,
    cardBorder: AppColors.cardBorder,
    pageBackdrop: AppColors.pageBackdrop,
    onBrand: AppColors.onBrand,
    textPrimary: AppColors.textPrimary,
    textMuted: AppColors.textMuted,
    textSubtle: AppColors.textSubtle,
    agentBlue: AppColors.agentBlue,
    agentBlueBg: AppColors.agentBlueBg,
    dealerOrange: AppColors.dealerOrange,
    dealerOrangeBg: AppColors.dealerOrangeBg,
    errorRed: AppColors.errorRed,
    errorBg: AppColors.errorBg,
    warnBg: AppColors.warnBg,
    warnText: AppColors.warnText,
    starColor: AppColors.starColor,
    mintAccent: AppColors.mintAccent,
  );

  /// The dark set.
  ///
  /// Two rules held throughout: the brand green is unchanged, so the emblem,
  /// the buttons and the header look like the same product in both themes;
  /// and every tint that was a pale wash of a colour becomes a deep wash of
  /// the same colour, with its text lightened to match.
  static const dark = AppPalette(
    teal: AppColors.teal,
    // Same value in both themes: what it carries is white either way.
    tealFill: AppColors.tealFill,
    tealDark: Color(0xFF2C4A39),
    // Was a pale wash behind icons and banners; now a deep one.
    tealLight: Color(0xFF1F2B25),
    // Barely a tint at all in the dark: a green wash over near-black turns
    // muddy long before it reads as brand colour.
    headerTint: Color(0xFF151C18),
    // These are the text ON tealLight, so they invert with it.
    tealText: Color(0xFFA8CDB8),
    tealText2: Color(0xFF93BCA5),
    background: Color(0xFF101312),
    surface: Color(0xFF191D1C),
    cardBorder: Color(0xFF2A302E),
    // Darker than the app itself, so the centred column still reads as the
    // page on a wide window.
    pageBackdrop: Color(0xFF0A0C0B),
    onBrand: AppColors.onBrand,
    textPrimary: Color(0xFFE8EBEA),
    textMuted: Color(0xFFA2ABA6),
    textSubtle: Color(0xFF8A938D),
    // Accents lighten so they stay legible on a dark surface; their
    // backgrounds darken to match.
    agentBlue: Color(0xFF7FA8E0),
    agentBlueBg: Color(0xFF1B2534),
    dealerOrange: Color(0xFFE0A05A),
    dealerOrangeBg: Color(0xFF33261A),
    errorRed: Color(0xFFF08575),
    errorBg: Color(0xFF33201E),
    warnBg: Color(0xFF332819),
    warnText: Color(0xFFE5B07A),
    starColor: Color(0xFFE0A94A),
    mintAccent: AppColors.mintAccent,
  );

  @override
  AppPalette copyWith({
    Color? teal,
    Color? tealFill,
    Color? tealDark,
    Color? tealLight,
    Color? headerTint,
    Color? tealText,
    Color? tealText2,
    Color? background,
    Color? surface,
    Color? cardBorder,
    Color? pageBackdrop,
    Color? onBrand,
    Color? textPrimary,
    Color? textMuted,
    Color? textSubtle,
    Color? agentBlue,
    Color? agentBlueBg,
    Color? dealerOrange,
    Color? dealerOrangeBg,
    Color? errorRed,
    Color? errorBg,
    Color? warnBg,
    Color? warnText,
    Color? starColor,
    Color? mintAccent,
  }) {
    return AppPalette(
      teal: teal ?? this.teal,
      tealFill: tealFill ?? this.tealFill,
      tealDark: tealDark ?? this.tealDark,
      tealLight: tealLight ?? this.tealLight,
      headerTint: headerTint ?? this.headerTint,
      tealText: tealText ?? this.tealText,
      tealText2: tealText2 ?? this.tealText2,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      cardBorder: cardBorder ?? this.cardBorder,
      pageBackdrop: pageBackdrop ?? this.pageBackdrop,
      onBrand: onBrand ?? this.onBrand,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      textSubtle: textSubtle ?? this.textSubtle,
      agentBlue: agentBlue ?? this.agentBlue,
      agentBlueBg: agentBlueBg ?? this.agentBlueBg,
      dealerOrange: dealerOrange ?? this.dealerOrange,
      dealerOrangeBg: dealerOrangeBg ?? this.dealerOrangeBg,
      errorRed: errorRed ?? this.errorRed,
      errorBg: errorBg ?? this.errorBg,
      warnBg: warnBg ?? this.warnBg,
      warnText: warnText ?? this.warnText,
      starColor: starColor ?? this.starColor,
      mintAccent: mintAccent ?? this.mintAccent,
    );
  }

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      teal: c(teal, other.teal),
      tealFill: c(tealFill, other.tealFill),
      tealDark: c(tealDark, other.tealDark),
      tealLight: c(tealLight, other.tealLight),
      headerTint: c(headerTint, other.headerTint),
      tealText: c(tealText, other.tealText),
      tealText2: c(tealText2, other.tealText2),
      background: c(background, other.background),
      surface: c(surface, other.surface),
      cardBorder: c(cardBorder, other.cardBorder),
      pageBackdrop: c(pageBackdrop, other.pageBackdrop),
      onBrand: c(onBrand, other.onBrand),
      textPrimary: c(textPrimary, other.textPrimary),
      textMuted: c(textMuted, other.textMuted),
      textSubtle: c(textSubtle, other.textSubtle),
      agentBlue: c(agentBlue, other.agentBlue),
      agentBlueBg: c(agentBlueBg, other.agentBlueBg),
      dealerOrange: c(dealerOrange, other.dealerOrange),
      dealerOrangeBg: c(dealerOrangeBg, other.dealerOrangeBg),
      errorRed: c(errorRed, other.errorRed),
      errorBg: c(errorBg, other.errorBg),
      warnBg: c(warnBg, other.warnBg),
      warnText: c(warnText, other.warnText),
      starColor: c(starColor, other.starColor),
      mintAccent: c(mintAccent, other.mintAccent),
    );
  }
}

/// `context.colors.teal` — the replacement for `AppColors.teal` in widgets.
extension AppPaletteContext on BuildContext {
  AppPalette get colors =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
