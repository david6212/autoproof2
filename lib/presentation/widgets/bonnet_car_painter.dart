import 'package:flutter/material.dart';

/// The splash's car, seen from the front, whose bonnet opens.
///
/// **Drawn, not the photograph.** Everywhere else the logo uses
/// `assets/layers/car.png`, and that stays; a picture cannot lift its own
/// bonnet, so the one screen that needs it to draws the car instead, to the
/// same silhouette — a white body whose windscreen, lamps and grille are cut
/// through to the shield behind it.
///
/// Painted in a 640×450 design space. The open bonnet stands above the roof
/// (up to y = -124), so this paints outside its own box on purpose: size the
/// box to the car, not to the raised bonnet.
class BonnetCarPainter extends CustomPainter {
  const BonnetCarPainter({
    required this.cutout,
    this.fold = 0,
    this.lift = 0,
    this.rod = 0,
  });

  /// The colour behind the car — its openings are painted in it.
  final Color cutout;

  /// 0 = bonnet shut over the bay, 1 = folded up into the hinge line.
  final double fold;

  /// 0 = raised bonnet flat on its hinge, 1 = standing open. May overshoot 1.
  final double lift;

  /// Opacity of the prop rod.
  final double rod;

  static const designSize = Size(640, 450);

  /// Where the bonnet meets the windscreen, and so where it hinges.
  static const hingeY = 152.0;

  static const _engine = Color(0xFF243A2F);
  static const _engineHi = Color(0xFF35503F);
  static const _engineLine = Color(0xFF4C6A58);
  static const _frame = Color(0xFFB7C7BE);
  static const _pressing = Color(0xFFBCCBC3);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / designSize.width, size.height / designSize.height);

    final white = Paint()..color = Colors.white;
    final hole = Paint()..color = cutout;

    // ---- body ----
    canvas.drawPath(
      Path()
        ..moveTo(150, 8)
        ..cubicTo(230, -2, 410, -2, 490, 8)
        ..cubicTo(520, 12, 540, 40, 555, 110)
        ..lineTo(572, 152)
        ..lineTo(612, 118)
        ..cubicTo(630, 112, 640, 128, 632, 142)
        ..cubicTo(622, 158, 600, 162, 590, 160)
        ..lineTo(596, 168)
        ..cubicTo(618, 190, 632, 230, 634, 290)
        ..lineTo(634, 404)
        ..cubicTo(634, 420, 624, 426, 610, 426)
        ..lineTo(540, 426)
        ..lineTo(540, 404)
        ..lineTo(100, 404)
        ..lineTo(100, 426)
        ..lineTo(30, 426)
        ..cubicTo(16, 426, 6, 420, 6, 404)
        ..lineTo(6, 290)
        ..cubicTo(8, 230, 22, 190, 44, 168)
        ..lineTo(50, 160)
        ..cubicTo(40, 162, 18, 158, 8, 142)
        ..cubicTo(0, 128, 10, 112, 28, 118)
        ..lineTo(68, 152)
        ..lineTo(85, 110)
        ..cubicTo(100, 40, 120, 12, 150, 8)
        ..close(),
      white,
    );

    // ---- engine bay: over the body, under the bonnet ----
    canvas.drawPath(_bay, Paint()..color = _engine);
    canvas.drawRRect(
      RRect.fromLTRBR(220, 178, 420, 240, const Radius.circular(14)),
      Paint()..color = _engineHi,
    );
    final line = Paint()..color = _engineLine;
    canvas.drawRRect(
        RRect.fromLTRBR(250, 192, 390, 202, const Radius.circular(5)), line);
    canvas.drawRRect(
        RRect.fromLTRBR(250, 214, 346, 224, const Radius.circular(5)), line);
    canvas.drawCircle(const Offset(150, 210), 18, Paint()..color = _engineHi);
    canvas.drawCircle(const Offset(490, 210), 18, Paint()..color = _engineHi);

    // ---- openings, showing the shield through ----
    canvas.drawPath(
      Path()
        ..moveTo(82, 150)
        ..lineTo(558, 150)
        ..lineTo(512, 30)
        ..cubicTo(470, 20, 170, 20, 128, 30)
        ..close(),
      hole,
    );
    canvas.drawPath(
      Path()
        ..moveTo(36, 238)
        ..cubicTo(80, 228, 132, 236, 158, 256)
        ..cubicTo(164, 276, 150, 300, 120, 300)
        ..lineTo(48, 300)
        ..cubicTo(32, 288, 28, 256, 36, 238)
        ..close(),
      hole,
    );
    canvas.drawPath(
      Path()
        ..moveTo(604, 238)
        ..cubicTo(560, 228, 508, 236, 482, 256)
        ..cubicTo(476, 276, 490, 300, 520, 300)
        ..lineTo(592, 300)
        ..cubicTo(608, 288, 612, 256, 604, 238)
        ..close(),
      hole,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(190, 272, 450, 356, const Radius.circular(20)),
      hole,
    );

    // ---- bonnet, shut: folds up into the hinge line ----
    final shut = (1 - fold).clamp(0.0, 1.0);
    if (shut > 0) {
      _aboutHinge(canvas, shut, () {
        canvas.drawPath(_bay, white);
        canvas.drawLine(
          const Offset(320, 156),
          const Offset(320, 258),
          Paint()
            ..color = const Color(0xFFE4ECE7)
            ..strokeWidth = 4,
        );
      });
    }

    // ---- bonnet, open: stands up out of the hinge, underside showing ----
    if (lift > 0) {
      _aboutHinge(canvas, lift, () => _paintRaisedBonnet(canvas));
    }

    if (rod > 0) {
      canvas.drawLine(
        const Offset(140, 160),
        const Offset(150, -30),
        Paint()
          ..color = const Color(0xFF8FA598).withValues(alpha: rod.clamp(0.0, 1.0))
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.restore();
  }

  static final Path _bay = Path()
    ..moveTo(98, 152)
    ..lineTo(542, 152)
    ..lineTo(578, 262)
    ..lineTo(62, 262)
    ..close();

  /// Scales the vertical about the hinge line: the shut bonnet, below it,
  /// collapses up into it; the raised one, above it, grows up out of it.
  void _aboutHinge(Canvas canvas, double sy, VoidCallback draw) {
    canvas.save();
    canvas.translate(0, hingeY);
    canvas.scale(1, sy);
    canvas.translate(0, -hingeY);
    draw();
    canvas.restore();
  }

  /// A raised bonnet seen from the front: the curved front lip at the top,
  /// the sides sweeping in to the hinge, and its underside — the stiffening
  /// frame, two pressed lightening holes and the spine, and the latch striker.
  void _paintRaisedBonnet(Canvas canvas) {
    final skin = Path()
      ..moveTo(104, 152)
      ..cubicTo(92, 92, 64, 10, 50, -62)
      ..cubicTo(44, -96, 58, -118, 92, -124)
      ..quadraticBezierTo(320, -160, 548, -124)
      ..cubicTo(582, -118, 596, -96, 590, -62)
      ..cubicTo(576, 10, 548, 92, 536, 152)
      ..close();
    canvas.drawPath(skin, Paint()..color = Colors.white);

    final underside = Path()
      ..moveTo(124, 150)
      ..cubicTo(113, 94, 88, 18, 75, -52)
      ..cubicTo(71, -80, 82, -98, 108, -102)
      ..quadraticBezierTo(320, -134, 532, -102)
      ..cubicTo(558, -98, 569, -80, 565, -52)
      ..cubicTo(552, 18, 527, 94, 516, 150)
      ..close();
    canvas.drawPath(
      underside,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEEF3F0), Color(0xFFC9D6CF)],
        ).createShader(const Rect.fromLTRB(0, -134, 640, 150)),
    );

    canvas.drawPath(
      Path()
        ..moveTo(150, 140)
        ..cubicTo(140, 92, 118, 28, 107, -36)
        ..cubicTo(104, -58, 112, -72, 132, -75)
        ..quadraticBezierTo(320, -104, 508, -75)
        ..cubicTo(528, -72, 536, -58, 533, -36)
        ..cubicTo(522, 28, 500, 92, 490, 140)
        ..close(),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeJoin = StrokeJoin.round
        ..color = _frame,
    );

    final pressing = Paint()..color = _pressing;
    canvas.drawPath(
      Path()
        ..moveTo(166, -40)
        ..quadraticBezierTo(230, -60, 290, -58)
        ..cubicTo(298, -20, 292, 40, 282, 96)
        ..quadraticBezierTo(224, 100, 184, 96)
        ..cubicTo(172, 40, 164, 0, 166, -40)
        ..close(),
      pressing,
    );
    canvas.drawPath(
      Path()
        ..moveTo(474, -40)
        ..quadraticBezierTo(410, -60, 350, -58)
        ..cubicTo(342, -20, 348, 40, 358, 96)
        ..quadraticBezierTo(416, 100, 456, 96)
        ..cubicTo(468, 40, 476, 0, 474, -40)
        ..close(),
      pressing,
    );
    canvas.drawLine(
      const Offset(320, -92),
      const Offset(320, 140),
      Paint()
        ..color = _frame
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(304, -112, 336, -94, const Radius.circular(6)),
      Paint()..color = const Color(0xFF9FB3A7),
    );
  }

  @override
  bool shouldRepaint(covariant BonnetCarPainter old) =>
      old.fold != fold ||
      old.lift != lift ||
      old.rod != rod ||
      old.cutout != cutout;
}
