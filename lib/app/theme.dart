import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_palette.dart';

/// BonnetCheck app theme — Heebo font, teal brand palette, clean fintech feel.
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
      // The app bar is no longer a green band. It was the loudest thing on
      // every screen and it competed with the content; on the page colour with
      // a hairline under it, the screen's own material is what you see first.
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.textPrimary,
        elevation: 0,
        // Material 3 tints the bar when content scrolls beneath it. That would
        // put the colour shift straight back, halfway down every scroll.
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        // What separates the bar from the page now that they share a colour.
        shape: Border(bottom: BorderSide(color: p.cardBorder)),
        // Icons in the OS status bar have to invert with the bar underneath
        // them, or they vanish. Flutter infers this from the background, but
        // inferring it is exactly what stops being true the next time somebody
        // overrides a single screen's bar.
        systemOverlayStyle: brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.tealFill,
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
          backgroundColor: p.tealFill,
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
          // Label is green ink on the page, so it takes the ink token (6.74:1
          // light / 8.09:1 dark). The border stays [teal] — an outline is a
          // graphic, and 3:1 is its floor.
          foregroundColor: p.tealText2,
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
