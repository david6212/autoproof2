import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_palette.dart';

/// OtoV app theme — Heebo font, teal brand palette, clean fintech feel.
///
/// Both themes are built from the same recipe; only the [AppPalette] differs.
/// Writing them separately is how a dark theme drifts out of step with the
/// light one.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light, AppPalette.light);

  static ThemeData get dark => _build(Brightness.dark, AppPalette.dark);

  static ThemeData _build(Brightness brightness, AppPalette p) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);

    return base.copyWith(
      // Widgets read their colours from here via `context.colors`.
      extensions: [p],
      scaffoldBackgroundColor: p.background,
      colorScheme: base.colorScheme.copyWith(
        primary: p.teal,
        secondary: p.mintAccent,
        surface: p.surface,
        error: p.errorRed,
        // Without this, Material's own surfaces (dialogs, list tiles, menus)
        // keep their default ink and go unreadable on the dark palette.
        onSurface: p.textPrimary,
      ),
      textTheme: GoogleFonts.heeboTextTheme(base.textTheme).apply(
        bodyColor: p.textPrimary,
        displayColor: p.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.teal,
        foregroundColor: p.onBrand,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.teal,
          foregroundColor: p.onBrand,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.heebo(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      // Filled/outlined buttons were styled inline at ~24 call sites; these
      // defaults mean a plain FilledButton/OutlinedButton already looks right.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.teal,
          foregroundColor: p.onBrand,
          // Height only — `Size.fromHeight` would set an INFINITE minimum
          // width and stretch every button, including dialog actions.
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: GoogleFonts.heebo(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.teal,
          side: BorderSide(color: p.teal),
          minimumSize: const Size(64, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: GoogleFonts.heebo(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: p.cardBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.teal, width: 2),
        ),
      ),
    );
  }
}
