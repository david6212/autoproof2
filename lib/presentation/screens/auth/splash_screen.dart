import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/klaro_logo.dart';

/// Animated KLARO splash — a Flutter port of the GSAP prototype:
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
                              painter: ShieldPainter(_green),
                            ),
                          ),
                        ),
                        // Car: opacity + drop from above, settling slightly
                        // above centre so the check sits at the shield's base.
                        Opacity(
                          opacity: _car.value.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(
                                0, (-90 * (1 - _car.value)) - 6 * _car.value),
                            child: Image.asset(
                              'assets/layers/car.png',
                              width: 72,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        // Checkmark: draws itself on, bottom-right.
                        Positioned(
                          right: 0,
                          bottom: 12,
                          child: CustomPaint(
                            size: const Size(48, 48),
                            painter: CheckPainter(_green, _check.value),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  // ---- Wordmark: KLARO's letters draw together ----
                  // One word, so the old two-halves convergence is replaced by
                  // letter-spacing settling from wide to tight as it fades in.
                  // Force LTR — the Latin mark must not flip in this RTL app.
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Opacity(
                      opacity: _text.value.clamp(0.0, 1.0),
                      child: Text(
                        AppStrings.appName,
                        style: _wordStyle.copyWith(
                          letterSpacing: 4 + 16 * (1 - _text.value),
                        ),
                      ),
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
