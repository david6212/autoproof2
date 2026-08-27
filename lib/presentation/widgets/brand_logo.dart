import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// The BonnetCheck mark exactly as it looks at the end of the splash animation:
/// a flat green shield + the car image + a green checkmark. Static (no
/// animation) so it can be reused anywhere a brand logo is needed. Pass
/// [withWordmark] to show the BonnetCheck wordmark beneath the emblem.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 120, this.withWordmark = false});

  /// Target width in logical pixels (height scales proportionally).
  final double size;

  /// When true, renders the BonnetCheck wordmark under the emblem.
  final bool withWordmark;

  static const _green = Color(0xFF558B6E);

  @override
  Widget build(BuildContext context) {
    // Center + explicit height so a stretching parent (e.g. a Column with
    // crossAxisAlignment.stretch) can't blow the logo up to full width.
    final emblem = Center(
      child: SizedBox(
        width: size,
        height: size * 150 / 140,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 140,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const CustomPaint(
                  size: Size(120, 135),
                  painter: ShieldPainter(_green),
                ),
                Transform.translate(
                  offset: const Offset(0, -6),
                  child: Image.asset(
                    'assets/layers/car.png',
                    width: 72,
                    fit: BoxFit.contain,
                  ),
                ),
                // Check on a white badge so it never blends into the shield.
                Positioned(
                  right: 0,
                  bottom: 2,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: _green, width: 3),
                    ),
                    child: const Center(
                      child: CustomPaint(
                        size: Size(34, 34),
                        painter: CheckPainter(_green, 1),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!withWordmark) return emblem;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        emblem,
        SizedBox(height: size * 0.12),
        BrandWordmark(fontSize: size * 0.30),
      ],
    );
  }
}

/// The name set so the mark *is* the second half of it.
///
/// The app was called BonnetCheck, and its wordmark ended in a V drawn as the
/// emblem's checkmark — name and mark as one idea rather than two things side
/// by side. "BonnetCheck" has no V, but it has something better: the second
/// word *names* the mark. So the mark plays it. The type reads "Bonnet" and
/// the check finishes the word, which is why it is set larger here than a
/// letterform would be — it is standing in for five letters, not one.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    super.key,
    this.fontSize = 34,
    this.color,
    this.checkColor,
    this.checkScale = 1.0,
    this.entrance = 1.0,
    this.checkProgress = 1.0,
  });

  final double fontSize;

  /// Both default to the theme — the wordmark has to stay legible on the
  /// dark background too, and a default value cannot read the theme.
  final Color? color;
  final Color? checkColor;

  /// Enlarges the check relative to the cap height. Above 1 it rises over the
  /// letters, which is the point on the splash — there the mark is the
  /// subject, not a piece of type.
  final double checkScale;

  /// 0 = the two halves start apart, 1 = joined. Drives the splash, where the
  /// name assembles the same way the emblem does: "Bonnet" in from the left,
  /// the check in from the right, meeting. Everywhere else it is simply 1.
  final double entrance;

  /// How much of the check's stroke is drawn, 0..1.
  final double checkProgress;

  @override
  Widget build(BuildContext context) {
    // A check is wider than it is tall and sits above the baseline, so it is
    // sized off cap height rather than the full em.
    // 0.86 rather than 0.72: this check replaces the word "Check", so it has
    // to carry more weight than the single letter it used to be.
    final capHeight = fontSize * 0.86 * checkScale;
    final ink = color ?? context.colors.textPrimary;
    final check = checkColor ?? context.colors.teal;

    // Each half travels this far, in opposite directions. Proportional to the
    // type size so the gesture is the same at any scale.
    final travel = fontSize * 2.2 * (1 - entrance.clamp(0.0, 1.0));

    // Latin mark in an RTL app — pin the direction so it never flips.
    return Directionality(
      textDirection: TextDirection.ltr,
      // A wordmark is a drawing that happens to be made of letters, and it
      // overflowed its slot at Android's 1.5x text size. Shrinking to fit is
      // the right answer rather than refusing to scale at all: it still grows
      // with the reader up to the width it has, and never past it.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Translating rather than re-laying-out: the Row keeps its slots, so
            // the mark never reflows while it assembles.
            Transform.translate(
              offset: Offset(-travel, 0),
              child: Text(
                'Bonnet',
                style: TextStyle(
                  // Bundled with the app rather than fetched from Google's
                  // servers at first paint — see the fonts: block in pubspec.
                  fontFamily: 'Poppins',
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: ink,
                  letterSpacing: 0.5,
                  height: 1,
                ),
              ),
            ),
            Padding(
              // Optical spacing: the check's open left arm needs less air than a
              // letter would, and it sits slightly off the baseline.
              padding: EdgeInsets.only(
                left: fontSize * 0.06,
                bottom: fontSize * 0.04,
              ),
              child: Transform.translate(
                offset: Offset(travel, 0),
                child: CustomPaint(
                  size: Size(capHeight * 1.05, capHeight),
                  painter: CheckPainter(check, checkProgress),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Flat shield outline + fill (viewBox 100×115).
class ShieldPainter extends CustomPainter {
  const ShieldPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 115);

    final outer =
        Path()
          ..moveTo(50, 5)
          ..cubicTo(75, 5, 95, 18, 95, 28)
          ..lineTo(95, 65)
          ..cubicTo(95, 92, 65, 108, 50, 112)
          ..cubicTo(35, 108, 5, 92, 5, 65)
          ..lineTo(5, 28)
          ..cubicTo(5, 18, 25, 5, 50, 5)
          ..close();
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    final inner =
        Path()
          ..moveTo(50, 14)
          ..cubicTo(70, 14, 87, 25, 87, 33)
          ..lineTo(87, 63)
          ..cubicTo(87, 85, 62, 98, 50, 102)
          ..cubicTo(38, 98, 13, 85, 13, 63)
          ..lineTo(13, 33)
          ..cubicTo(13, 25, 30, 14, 50, 14)
          ..close();
    canvas.drawPath(inner, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant ShieldPainter old) => old.color != color;
}

/// Checkmark that can draw itself on (viewBox 60×60). [progress] 0..1.
class CheckPainter extends CustomPainter {
  const CheckPainter(this.color, this.progress);
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 60, size.height / 60);

    final full =
        Path()
          ..moveTo(12, 30)
          ..lineTo(26, 44)
          ..lineTo(48, 16);

    final drawn = Path();
    for (final m in full.computeMetrics()) {
      drawn.addPath(
        m.extractPath(0, m.length * progress.clamp(0.0, 1.0)),
        Offset.zero,
      );
    }

    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant CheckPainter old) =>
      old.progress != progress || old.color != color;
}
