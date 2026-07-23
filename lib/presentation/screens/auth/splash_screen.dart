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
                              size: Size(64, 50),
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

/// A cleaner, more realistic front-view sedan: smooth white silhouette with
/// a green outline, sloped windshield, swept headlights and a grille.
class _CarPainter extends CustomPainter {
  const _CarPainter(this.accent);
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 78);

    final white = Paint()..color = Colors.white;
    final green = Paint()..color = accent;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeJoin = StrokeJoin.round
      ..color = accent;

    // Body silhouette (roof + shoulders + rounded lower body).
    final body = Path()
      ..moveTo(10, 52)
      ..quadraticBezierTo(10, 43, 19, 41)
      ..lineTo(28, 41)
      ..quadraticBezierTo(31, 24, 43, 22)
      ..lineTo(57, 22)
      ..quadraticBezierTo(69, 24, 72, 41)
      ..lineTo(81, 41)
      ..quadraticBezierTo(90, 43, 90, 52)
      ..lineTo(90, 61)
      ..quadraticBezierTo(90, 67, 83, 67)
      ..lineTo(17, 67)
      ..quadraticBezierTo(10, 67, 10, 61)
      ..close();
    canvas.drawPath(body, white);
    canvas.drawPath(body, outline);

    // Windshield / roof glass.
    final windshield = Path()
      ..moveTo(33, 41)
      ..lineTo(37, 28)
      ..quadraticBezierTo(38, 26, 41, 26)
      ..lineTo(59, 26)
      ..quadraticBezierTo(62, 26, 63, 28)
      ..lineTo(67, 41)
      ..close();
    canvas.drawPath(windshield, green);

    // Swept headlights.
    final lh = Path()
      ..moveTo(15, 46)
      ..lineTo(34, 45)
      ..lineTo(33, 50)
      ..lineTo(15, 51)
      ..close();
    final rh = Path()
      ..moveTo(85, 46)
      ..lineTo(66, 45)
      ..lineTo(67, 50)
      ..lineTo(85, 51)
      ..close();
    canvas.drawPath(lh, green);
    canvas.drawPath(rh, green);

    // Grille + lower bumper intake.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(42, 53, 16, 6), const Radius.circular(2)),
        green);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(28, 61, 44, 4), const Radius.circular(2)),
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
