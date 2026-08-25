import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/onboarding_seen_provider.dart';
import '../../widgets/brand_logo.dart';

/// Animated BonnetCheck splash.
///
/// The shield scales in, then the car and the check travel toward each other
/// from opposite sides and meet inside it — the car being approved, in one
/// gesture. They share an interval and a curve so the convergence is
/// symmetrical, and the check finishes drawing itself just before it lands.
/// Then the name does the same thing: "Bonnet" in from the left, its check in from
/// the right, meeting — so the check the shield just drew reappears as the V,
/// arriving the same way. The V is enlarged there because on this screen it is
/// the subject rather than a letterform.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF558B6E);
  static const _bg = Color(0xFFF8FAF9);

  late final AnimationController _c;
  late final Animation<double> _shield; // 0..1  (0–450ms)
  late final Animation<double> _car; //    0..1  (350–1000ms)
  late final Animation<double> _check; //  0..1  (350–1000ms)
  late final Animation<double> _text; //   0..1  (1000–1700ms)

  /// How far out the car and the check start, in logical pixels. They travel
  /// the same distance from opposite sides so they meet in the middle.
  static const _approach = 130.0;

  /// Total length of the intro. The wordmark's own convergence needs room
  /// after the emblem's, so this is longer than the emblem alone required.
  static const _introMs = 1700;

  bool _exiting = false;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    // Total intro = 1400ms; each stage is an Interval within it.
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _introMs),
    );

    Animation<double> stage(double startMs, double endMs, Curve curve) {
      return CurvedAnimation(
        parent: _c,
        curve: Interval(startMs / _introMs, endMs / _introMs, curve: curve),
      );
    }

    _shield = stage(0, 450, Curves.easeOutBack);
    // Same interval and same curve for both, so they converge symmetrically.
    // easeInOutCubic rather than a back-out: back-out puts ~95% of the travel
    // into the first fifth of the window, which reads as a snap rather than
    // an approach. This accelerates out and decelerates into the meeting.
    _car = stage(350, 1000, Curves.easeInOutCubic);
    _check = stage(350, 1000, Curves.easeInOutCubic);
    // Same curve as the emblem's convergence, so the name assembles with the
    // same motion rather than a different one.
    _text = stage(1000, 1700, Curves.easeInOutCubic);

    _c.forward();

    // Hold ~1.4s after the intro finishes, then fade out and route on.
    _holdTimer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) setState(() => _exiting = true);
    });
  }

  Future<void> _goNext() async {
    if (!mounted) return;
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user != null) {
      context.go('/home');
      return;
    }

    // A guest who has already seen the slides goes straight in. Before this,
    // the three screens and then the login wall ran on every launch for anyone
    // without an account — and reading the registry needs no account, so that
    // was most of the product behind a pitch the person had already read.
    final seen = await OnboardingSeen.get();
    if (!mounted) return;
    context.go(seen ? '/home' : '/onboarding');
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
                              painter: ShieldPainter(_green),
                            ),
                          ),
                        ),
                        // Car: comes in from the left, settling slightly above
                        // centre so the check has the shield's base to itself.
                        Opacity(
                          opacity: _car.value.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(
                              -_approach * (1 - _car.value),
                              -6 * _car.value,
                            ),
                            child: Image.asset(
                              'assets/layers/car.png',
                              width: 72,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        // Check: comes to meet it from the right, drawing
                        // itself on the way. The stroke runs slightly ahead of
                        // the travel so it is complete as it lands.
                        Positioned(
                          right: 0,
                          bottom: 8,
                          child: Opacity(
                            opacity: _check.value.clamp(0.0, 1.0),
                            child: Transform.translate(
                              offset:
                                  Offset(_approach * (1 - _check.value), 0),
                              child: CustomPaint(
                                size: const Size(62, 62),
                                painter: CheckPainter(
                                  _green,
                                  (_check.value * 1.3).clamp(0.0, 1.0),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  // ---- Wordmark ----
                  // The same mark used everywhere else, driven through its
                  // entrance: the two halves come together exactly as the car
                  // and the check just did, and its V draws itself on arrival.
                  Opacity(
                    opacity: _text.value.clamp(0.0, 1.0),
                    child: BrandWordmark(
                      fontSize: 30,
                      checkScale: 1.4,
                      entrance: _text.value.clamp(0.0, 1.0),
                      checkProgress: (_text.value * 1.3).clamp(0.0, 1.0),
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
}
