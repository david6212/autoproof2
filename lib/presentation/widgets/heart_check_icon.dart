import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// A heart with the brand's check inside it.
///
/// Saving a car is a heart everywhere in the app, and ticking one is the
/// gesture on Discover. This is both: the shape people already read as
/// "saved", carrying the mark the product is named after.
///
/// The check is the same three points as [CheckPainter] in the logo — the V
/// of the wordmark — so it is literally the brand's tick, not a generic one.
class HeartCheckIcon extends StatelessWidget {
  const HeartCheckIcon({
    super.key,
    this.size = 24,
    this.filled = false,
    this.color,
    this.checkColor,
  });

  final double size;

  /// Filled heart with the check knocked out in [checkColor]; otherwise an
  /// outlined heart with the check drawn in the same ink.
  final bool filled;

  final Color? color;

  /// Only used when [filled]. Defaults to the on-brand white, since a filled
  /// heart is a brand-coloured surface.
  final Color? checkColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HeartCheckPainter(
          color: color ?? context.colors.teal,
          checkColor: checkColor ?? context.colors.onBrand,
          filled: filled,
        ),
      ),
    );
  }
}

class _HeartCheckPainter extends CustomPainter {
  const _HeartCheckPainter({
    required this.color,
    required this.checkColor,
    required this.filled,
  });

  final Color color;
  final Color checkColor;
  final bool filled;

  /// Drawn in a 24×24 box and scaled, so every size keeps the proportions.
  static const _box = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _box, size.height / _box);

    final heart = Path()
      ..moveTo(12, 21)
      ..cubicTo(4, 14.6, 2, 11.6, 2, 8.6)
      ..cubicTo(2, 5.5, 4.4, 3.2, 7.4, 3.2)
      ..cubicTo(9.4, 3.2, 11.1, 4.2, 12, 5.8)
      ..cubicTo(12.9, 4.2, 14.6, 3.2, 16.6, 3.2)
      ..cubicTo(19.6, 3.2, 22, 5.5, 22, 8.6)
      ..cubicTo(22, 11.6, 20, 14.6, 12, 21)
      ..close();

    canvas.drawPath(
      heart,
      Paint()
        ..color = color
        ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 1.9
        ..strokeJoin = StrokeJoin.round,
    );

    // The logo's check (12,30 → 26,44 → 48,16 in its own 60 box), placed in
    // the heart's upper body where there is room for it.
    final check = Path()
      ..moveTo(8.1, 10.9)
      ..lineTo(10.9, 13.7)
      ..lineTo(16.3, 7.7);

    canvas.drawPath(
      check,
      Paint()
        ..color = filled ? checkColor : color
        ..style = PaintingStyle.stroke
        // Heavier than the heart's outline so the tick still reads at the
        // 20px the tab bar draws it at.
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_HeartCheckPainter old) =>
      old.color != color || old.checkColor != checkColor || old.filled != filled;
}

/// Tab-bar form, matching the signature [NavTab] expects.
///
/// Selected, the tab is a filled teal pill: the heart takes the pill's
/// foreground and the check is drawn in the pill's own colour, so it reads as
/// cut out of the heart. Unselected there is no pill, so it is an outline.
Widget savedTabIcon(bool selected, Color fg, Color bg) => HeartCheckIcon(
      size: 22,
      filled: selected,
      color: fg,
      checkColor: bg,
    );
