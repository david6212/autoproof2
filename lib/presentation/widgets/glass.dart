import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import 'photo_viewer.dart';

/// The bottom space a page under the floating navigation bar must leave so its
/// last row can scroll clear of the bar. Zero anywhere the bar is not.
double navClearance(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom;

/// An app bar for a screen whose content runs underneath it — a map, or a
/// listing. Pair it with `extendBodyBehindAppBar: true` and pad the top of the
/// content with `MediaQuery.paddingOf(context).top`.
AppBar glassAppBar(
  BuildContext context, {
  Widget? title,
  Widget? leading,
  List<Widget>? actions,
}) {
  return AppBar(
    title: title,
    leading: leading,
    actions: actions,
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    shape: Border(
      bottom: BorderSide(
        color: context.colors.cardBorder.withValues(alpha: 0.6),
      ),
    ),
    flexibleSpace: const Glass(border: false, child: SizedBox.expand()),
  );
}

/// What sits behind a [Glass] surface, which decides what it is made of.
enum GlassTone {
  /// The app's own surface, frosted: bars and panels that float over the page,
  /// a list, or a map. Carries dark ink in light mode and light ink in dark.
  surface,

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

  /// How much of the surface colour covers what is behind. Light mode needs
  /// more than dark: grey ink on frosted white over a black photo loses
  /// contrast faster than light ink on frosted black over a white one.
  static const surfaceAlphaLight = 0.86;
  static const surfaceAlphaDark = 0.87;

  /// Photographs keep the scrim [PhotoChip] was measured at: glass adds the
  /// blur and the rim, never less darkness.
  static const smokeAlpha = PhotoChip.scrimAlpha;

  static const blurSigma = 18.0;

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
      GlassTone.smoke => PhotoChip.scrim(smokeAlpha),
    };
  }

  @override
  Widget build(BuildContext context) {
    final real = enabledFor(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    final rim = switch (tone) {
      GlassTone.surface =>
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
              real && tone == GlassTone.surface
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
