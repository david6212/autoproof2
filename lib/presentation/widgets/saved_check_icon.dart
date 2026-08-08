import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// The "saved" mark: the brand's check, on its own.
///
/// This replaced a heart with a check tucked inside it. At the 20px the card
/// draws it at, two shapes in one glyph turned into a smudge — and the heart
/// was doing the talking while the check, which is the thing the product is
/// named after, was the part that got lost.
///
/// The path is the same three points as `CheckPainter` in the logo (12,30 →
/// 26,44 → 48,16 in a 60 box), so this is literally the V of the wordmark
/// rather than a generic tick.
///
/// State is carried by weight and colour, never by adding a second shape: a
/// saved item draws a heavier stroke, and the container it sits in — the
/// card's button, the tab bar's pill — changes fill. That keeps one silhouette
/// at every size.
class SavedCheckIcon extends StatelessWidget {
  const SavedCheckIcon({
    super.key,
    this.size = 24,
    this.filled = false,
    this.color,
  });

  final double size;

  /// The saved state. Draws the same check with a heavier stroke.
  final bool filled;

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CheckPainter(color: color ?? context.colors.teal, bold: filled),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter({required this.color, required this.bold});

  final Color color;
  final bool bold;

  /// The logo's own coordinate space, so the proportions carry over exactly.
  static const _box = 60.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _box, size.height / _box);

    final check = Path()
      ..moveTo(12, 30)
      ..lineTo(26, 44)
      ..lineTo(48, 16);

    canvas.drawPath(
      check,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        // The logo draws this at 10. Slightly lighter here so it reads as an
        // icon rather than as the emblem, and lighter again when unsaved.
        ..strokeWidth = bold ? 9.5 : 7.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.color != color || old.bold != bold;
}

/// Tab-bar form, matching the signature `NavTab` expects.
///
/// Selected, the tab is already a filled teal pill, so the check simply takes
/// the pill's foreground and thickens. `bg` is unused now — there is no
/// knocked-out shape left to fill — but the signature is fixed by [NavTab].
Widget savedTabIcon(bool selected, Color fg, Color bg) => SavedCheckIcon(
      size: 22,
      filled: selected,
      color: fg,
    );
