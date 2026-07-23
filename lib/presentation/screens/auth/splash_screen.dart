import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/auth_provider.dart';

/// Animated AutoProof splash — a Flutter port of the GSAP prototype:
/// shield scales in → car drops into the shield → AUTO/PROOF converge →
/// the checkmark draws itself on. Then hold and fade out to the app.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF558B6E);
  static const _ink = Color(0xFF1A202C);
  static const _bg = Color(0xFFF8FAF9);

  late final AnimationController _c;
  late final Animation<double> _shield; // 0..1  (0–500ms)
  late final Animation<double> _car; //    0..1  (300–900ms)
  late final Animation<double> _text; //   0..1  (600–1100ms)
  late final Animation<double> _check; //  0..1  (1000–1400ms)

  bool _exiting = false;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    // Total intro = 1400ms; each stage is an Interval within it.
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    Animation<double> stage(double startMs, double endMs, Curve curve) {
      return CurvedAnimation(
        parent: _c,
        curve: Interval(startMs / 1400, endMs / 1400, curve: curve),
      );
    }

    _shield = stage(0, 500, Curves.easeOutBack); // back.out
    _car = stage(300, 900, Curves.bounceOut); //   bounce.out
    _text = stage(600, 1100, Curves.easeOut); //   power2.out
    _check = stage(1000, 1400, Curves.easeInOut); // power1.inOut

    _c.forward();

    // Hold ~1.4s after the intro finishes, then fade out and route on.
    _holdTimer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) setState(() => _exiting = true);
    });
  }

  void _goNext() {
    if (!mounted) return;
    final user = ref.read(authRepositoryProvider).currentUser;
    context.go(user != null ? '/home' : '/onboarding');
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: AnimatedOpacity(
        opacity: _exiting ? 0 : 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeIn,
        onEnd: () {
          if (_exiting) _goNext();
        },
        child: Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ---- Logo box (shield + car + check) ----
                  SizedBox(
                    width: 140,
                    height: 150,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Shield: opacity + scale-in.
                        Opacity(
                          opacity: _shield.value.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: 0.8 + 0.2 * _shield.value,
                            child: const CustomPaint(
                              size: Size(120, 135),
                              painter: _ShieldPainter(_green),
                            ),
                          ),
                        ),
                        // Car: opacity + drop from above into the shield.
                        Opacity(
                          opacity: _car.value.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, -90 * (1 - _car.value)),
                            child: const CustomPaint(
                              size: Size(58, 48),
                              painter: _CarPainter(_green),
                            ),
                          ),
                        ),
                        // Checkmark: draws itself on, bottom-right.
                        Positioned(
                          right: 0,
                          bottom: 12,
                          child: CustomPaint(
                            size: const Size(48, 48),
                            painter: _CheckPainter(_green, _check.value),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  // ---- Wordmark: AUTO from left, PROOF from right ----
                  // Force LTR so "AUTO" stays left of "PROOF" (the app is RTL).
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Opacity(
                          opacity: _text.value.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(-120 * (1 - _text.value), 0),
                            child: Text('AUTO', style: _wordStyle),
                          ),
                        ),
                        Opacity(
                          opacity: _text.value.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(120 * (1 - _text.value), 0),
                            child: Text('PROOF', style: _wordStyle),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  TextStyle get _wordStyle => GoogleFonts.montserrat(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: 2,
        color: _ink,
      );
}

// ----------------- Painters (ported from the SVG paths) -----------------

class _ShieldPainter extends CustomPainter {
  const _ShieldPainter(this.color);
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
  bool shouldRepaint(covariant _ShieldPainter old) => old.color != color;
}

class _CarPainter extends CustomPainter {
  const _CarPainter(this.accent);
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 80);
    final white = Paint()..color = Colors.white;
    final green = Paint()..color = accent;

    final roof = Path()
      ..moveTo(25, 32)
      ..cubicTo(30, 18, 38, 12, 50, 12)
      ..cubicTo(62, 12, 70, 18, 75, 32)
      ..lineTo(82, 48)
      ..lineTo(18, 48)
      ..close();
    canvas.drawPath(roof, white);

    final body = Path()
      ..moveTo(12, 48)
      ..cubicTo(10, 48, 8, 51, 8, 56)
      ..lineTo(10, 68)
      ..cubicTo(10, 72, 14, 74, 18, 74)
      ..lineTo(22, 74)
      ..lineTo(22, 70)
      ..lineTo(78, 70)
      ..lineTo(78, 74)
      ..lineTo(82, 74)
      ..cubicTo(86, 74, 90, 72, 90, 68)
      ..lineTo(92, 56)
      ..cubicTo(92, 51, 90, 48, 88, 48)
      ..close();
    canvas.drawPath(body, white);

    canvas.drawOval(
        Rect.fromCenter(center: const Offset(24, 58), width: 14, height: 8),
        green);
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(76, 58), width: 14, height: 8),
        green);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(40, 57, 20, 7), const Radius.circular(2)),
        green);
  }

  @override
  bool shouldRepaint(covariant _CarPainter old) => old.accent != accent;
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter(this.color, this.progress);
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 60, size.height / 60);

    final full = Path()
      ..moveTo(12, 30)
      ..lineTo(26, 44)
      ..lineTo(48, 16);

    // Draw only the first `progress` fraction of the stroke.
    final metrics = full.computeMetrics().toList();
    final drawn = Path();
    for (final m in metrics) {
      drawn.addPath(m.extractPath(0, m.length * progress.clamp(0.0, 1.0)),
          Offset.zero);
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
  bool shouldRepaint(covariant _CheckPainter old) =>
      old.progress != progress || old.color != color;
}
