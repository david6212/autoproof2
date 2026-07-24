import 'package:flutter/material.dart';

/// A small side-view car silhouette that varies by body type
/// (משפחתי / קרוסאובר / ספורט / חשמלי / היברידי).
class CarTypeIcon extends StatelessWidget {
  const CarTypeIcon({
    super.key,
    required this.type,
    required this.color,
    this.width = 64,
  });

  final String type;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, width * 0.52),
      painter: _CarTypePainter(type, color),
    );
  }
}

class _CarTypePainter extends CustomPainter {
  const _CarTypePainter(this.type, this.color);
  final String type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 52);
    final body = Paint()..color = color;
    final hub = Paint()..color = Colors.white;

    late final Path shape;
    switch (type) {
      case 'קרוסאובר':
        shape = Path()
          ..moveTo(6, 40)
          ..lineTo(8, 26)
          ..lineTo(22, 24)
          ..lineTo(30, 14)
          ..lineTo(70, 14)
          ..lineTo(78, 24)
          ..lineTo(94, 26)
          ..lineTo(94, 40)
          ..close();
        break;
      case 'ספורט':
        shape = Path()
          ..moveTo(6, 40)
          ..lineTo(8, 33)
          ..lineTo(28, 31)
          ..lineTo(41, 23)
          ..lineTo(60, 23)
          ..lineTo(88, 33)
          ..lineTo(94, 35)
          ..lineTo(94, 40)
          ..close();
        break;
      default: // משפחתי / חשמלי / היברידי share the sedan body
        shape = Path()
          ..moveTo(6, 40)
          ..lineTo(8, 30)
          ..lineTo(24, 28)
          ..lineTo(34, 18)
          ..lineTo(66, 18)
          ..lineTo(76, 28)
          ..lineTo(94, 30)
          ..lineTo(94, 40)
          ..close();
    }
    canvas.drawPath(shape, body);

    // Wheels + white hubs.
    for (final cx in [26.0, 74.0]) {
      canvas.drawCircle(Offset(cx, 42), 8, body);
      canvas.drawCircle(Offset(cx, 42), 3, hub);
    }

    // Fuel badge above the roof.
    if (type == 'חשמלי') {
      final bolt = Path()
        ..moveTo(52, 2)
        ..lineTo(46, 12)
        ..lineTo(50, 12)
        ..lineTo(48, 20)
        ..lineTo(56, 9)
        ..lineTo(51, 9)
        ..close();
      canvas.drawPath(bolt, body);
    } else if (type == 'היברידי') {
      final leaf = Path()
        ..moveTo(50, 3)
        ..quadraticBezierTo(60, 6, 50, 18)
        ..quadraticBezierTo(40, 6, 50, 3)
        ..close();
      canvas.drawPath(leaf, body);
    }
  }

  @override
  bool shouldRepaint(covariant _CarTypePainter old) =>
      old.type != type || old.color != color;
}
