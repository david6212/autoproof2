import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import 'photo_viewer.dart';

/// The bottom space a page under the floating navigation bar must leave so its
/// last row can scroll clear of the bar. Zero anywhere the bar is not.
double navClearance(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom;

/// An app bar for a screen whose content runs underneath it — a map, or a
/// listing: a rounded glass bar floating just below the status bar. Pair it
/// with `extendBodyBehindAppBar: true` and pad the top of the content with
/// `MediaQuery.paddingOf(context).top`, read from inside the Scaffold.
AppBar glassAppBar(
  BuildContext context, {
  Widget? title,
  Widget? leading,
  List<Widget>? actions,
}) {
  final top = MediaQuery.paddingOf(context).top;
  return AppBar(
    title: title,
    leading: leading == null
        ? null
        : Padding(padding: const EdgeInsetsDirectional.only(start: 6), child: leading),
    actions: [...?actions, const SizedBox(width: 6)],
    toolbarHeight: kToolbarHeight + 12,
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    foregroundColor: context.colors.textPrimary,
    elevation: 0,
    scrolledUnderElevation: 0,
    // No hairline: the bar floats, and its rim is the edge.
    shape: const Border(),
    flexibleSpace: Padding(
      padding: EdgeInsets.fromLTRB(10, top + 6, 10, 6),
      child: Glass(
        borderRadius: BorderRadius.circular(20),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

/// What sits behind a [Glass] surface, which decides what it is made of.
enum GlassTone {
  /// A bar floating over content: the navigation, the title bar, the action
  /// bar. The most see-through — and so only full-strength ink on it
  /// (`textPrimary`, or white on a filled button), never grey or green ink.
  surface,

  /// A panel that carries running text in its own right — the sheet over a
  /// map, the navigate sheet. Frosted more heavily, so grey secondary text on
  /// it stays readable.
  panel,

  /// Smoked: controls that sit on a photograph. Always dark with white ink,
  /// because the photograph can be any colour — including a white car.
  smoke,
}

/// A frosted surface: the page behind it blurred, and tinted enough that the
/// text on it is readable whatever scrolls underneath.
///
/// **Only where something is behind it.** Glass over a plain background is a
/// grey card. It is for surfaces that float over content — the bottom
/// navigation, bars and panels over a map, the listing's action bar, labels
/// on a photograph — and not for cards, forms or notices, where the reading
/// matters more than the depth.
///
/// **The tint is measured, not chosen for looks.** A pretty glass lets a dark
/// photo scroll under grey 10.5px labels; the opacities below are the lowest
/// at which the worst thing that can pass beneath still leaves the text above
/// 4.5:1 — `glass_test` pins each one. That is why this is less transparent
/// than the sketch it came from.
///
/// **Solid under high contrast.** Somebody who asked their phone for more
/// contrast gets the same surfaces without the see-through.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.tone = GlassTone.surface,
    this.borderRadius = BorderRadius.zero,
    this.padding,
    this.border = true,
  });

  final Widget child;
  final GlassTone tone;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool border;

  /// How much of the surface colour covers what is behind, for bars. The
  /// lowest at which `textPrimary` stays above 4.5:1 over the worst thing that
  /// can pass beneath (black under light glass, white under dark).
  static const surfaceAlphaLight = 0.58;
  static const surfaceAlphaDark = 0.68;

  /// For panels, where grey text (`textMuted`) and green ink sit on the glass.
  static const panelAlphaLight = 0.86;
  static const panelAlphaDark = 0.87;

  /// Photographs keep the scrim [PhotoChip] was measured at: glass adds the
  /// blur and the rim, never less darkness.
  static const smokeAlpha = PhotoChip.scrimAlpha;

  static const blurSigma = 22.0;

  /// Whether this device should get real glass.
  static bool enabledFor(BuildContext context) =>
      !(MediaQuery.maybeHighContrastOf(context) ?? false);

  /// The tint for [tone] in the current theme, exposed so tests measure the
  /// colour actually painted.
  static Color tint(
    BuildContext context,
    GlassTone tone, {
    bool solid = false,
  }) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch (tone) {
      GlassTone.surface =>
        solid
            ? colors.surface
            : colors.surface.withValues(
              alpha: dark ? surfaceAlphaDark : surfaceAlphaLight,
            ),
      GlassTone.panel =>
        solid
            ? colors.surface
            : colors.surface.withValues(
              alpha: dark ? panelAlphaDark : panelAlphaLight,
            ),
      GlassTone.smoke => PhotoChip.scrim(smokeAlpha),
    };
  }

  @override
  Widget build(BuildContext context) {
    final real = enabledFor(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    final rim = switch (tone) {
      GlassTone.surface || GlassTone.panel =>
        dark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.7),
      GlassTone.smoke => Colors.white.withValues(alpha: 0.18),
    };

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: tint(context, tone, solid: !real),
        borderRadius: borderRadius,
        border:
            border
                ? Border.all(
                  color: real ? rim : context.colors.cardBorder,
                  width: tone == GlassTone.smoke ? 0.8 : 1,
                )
                : null,
      ),
      // A faint light catching the top edge — the difference between frosted
      // glass and a translucent grey rectangle. Its own layer: a gradient on
      // the same decoration would replace the tint rather than sit on it.
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient:
              real && tone != GlassTone.smoke
                  ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: dark ? 0.04 : 0.22),
                      Colors.white.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.5],
                  )
                  : null,
        ),
        child:
            padding == null ? child : Padding(padding: padding!, child: child),
      ),
    );

    if (real) {
      surface = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: surface,
        ),
      );
    }

    return surface;
  }
}
