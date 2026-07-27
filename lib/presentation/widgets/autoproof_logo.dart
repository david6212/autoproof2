import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// The AutoProof mark exactly as it looks at the end of the splash animation:
/// a flat green shield + the car image + a green checkmark. Static (no
/// animation) so it can be reused anywhere a brand logo is needed. Pass
/// [withWordmark] to show the "AutoProof" wordmark beneath the emblem.
class AutoproofLogo extends StatelessWidget {
  const AutoproofLogo({super.key, this.size = 120, this.withWordmark = false});

  /// Target width in logical pixels (height scales proportionally).
  final double size;

  /// When true, renders the "AutoProof" wordmark under the emblem.
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
                // Bigger checkmark, scaled to the emblem.
                const Positioned(
                  right: 0,
                  bottom: 6,
                  child: CustomPaint(
                    size: Size(64, 64),
                    painter: CheckPainter(_green, 1),
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
        Text(
          'AutoProof',
          style: TextStyle(
            fontSize: size * 0.34,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
            height: 1,
          ),
        ),
      ],
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

    final outer = Path()
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

    final inner = Path()
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

    final full = Path()
      ..moveTo(12, 30)
      ..lineTo(26, 44)
      ..lineTo(48, 16);

    final drawn = Path();
    for (final m in full.computeMetrics()) {
      drawn.addPath(
          m.extractPath(0, m.length * progress.clamp(0.0, 1.0)), Offset.zero);
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
