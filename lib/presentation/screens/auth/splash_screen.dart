import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/onboarding_seen_provider.dart';
import '../../widgets/bonnet_car_painter.dart';
import '../../widgets/brand_logo.dart';

/// Animated BonnetCheck splash.
///
/// The name, acted out. The shield appears; a car drives in from far away and
/// stops inside it; its **bonnet** opens; the **check** lands beside it. Then
/// the name does what it has always done — "Bonnet" in from the left, its V in
/// from the right, meeting — so the check the emblem just drew reappears as the
/// V, arriving the same way.
///
/// The car here is painted ([BonnetCarPainter]), not the photograph the logo
/// uses everywhere else: a picture cannot open its own bonnet.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF558B6E);
  static const _bg = Color(0xFFF8FAF9);

  /// Total length of the intro, in ms. Every beat is a window inside it.
  static const _introMs = 3050;

  /// How long the finished mark is held before the screen fades away.
  static const _holdMs = 1100;

  late final AnimationController _c;

  bool _exiting = false;
  bool _started = false;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _introMs),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    // Somebody who has asked the OS to reduce motion gets the finished mark,
    // held for the same beat, and no car driving at them.
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _c.value = 1;
    } else {
      _c.forward();
    }
    _holdTimer = Timer(
      Duration(milliseconds: (still ? 0 : _introMs) + _holdMs),
      () {
        if (mounted) setState(() => _exiting = true);
      },
    );
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

  static double _clamp(double v) => v.clamp(0.0, 1.0);

  /// Progress through the window [a]..[b] ms of the intro, 0..1.
  static double _seg(double ms, double a, double b) =>
      _clamp((ms - a) / (b - a));

  /// Overshoots past 1 and settles — so everything it drives must clamp
  /// before it reaches an Opacity.
  static double _outBack(double x) {
    const c1 = 1.70158, c3 = c1 + 1;
    final t = x - 1;
    return 1 + c3 * t * t * t + c1 * t * t;
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
              final ms = _c.value * _introMs;

              // 1 · the shield, the destination.
              final shieldIn = _seg(ms, 0, 300);

              // 2 · the car arrives. Apparent size goes as 1 / distance: a car
              // braking toward you stays small for most of the approach and
              // fills out only in the last few metres. The springs dip a
              // little as it stops.
              final arrive = _seg(ms, 200, 1200);
              final near = 1 - (1 - arrive) * (1 - arrive);
              final carScale = 1 / (1 + 14 * (1 - near));
              final dip = ms > 1150 && ms < 1400
                  ? math.sin(_seg(ms, 1150, 1400) * math.pi) * 2
                  : 0.0;
              final carY = 2 + (1 - carScale) * -18 + dip;

              // 3 · the bonnet: the shut panel folds into the hinge, the lid
              // stands up out of it, overshoots a touch, settles on its rod.
              final fold =
                  Curves.easeInOutCubic.transform(_seg(ms, 1300, 1550));
              final up = _seg(ms, 1450, 1950);
              final lift = up <= 0 ? 0.0 : math.max(0.0, _outBack(up));
              final rod = _seg(ms, 1850, 1950);

              // 4 · the check lands beside it and draws itself.
              final checkIn = _seg(ms, 1950, 2350);
              final checkScale = math.max(0.0, 0.4 + 0.6 * _outBack(checkIn));
              final checkDraw = _clamp(_seg(ms, 2000, 2350) * 1.15);

              // 5 · the name, exactly as before: same curve, same entrance.
              final text =
                  Curves.easeInOutCubic.transform(_seg(ms, 2350, 3050));

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 140,
                    height: 150,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Opacity(
                          opacity: _clamp(shieldIn / 0.6),
                          child: Transform.scale(
                            scale: 0.8 + 0.2 * _outBack(shieldIn),
                            child: const CustomPaint(
                              size: Size(120, 135),
                              painter: ShieldPainter(_green),
                            ),
                          ),
                        ),
                        // Its shadow on the road, growing with it.
                        Opacity(
                          opacity: _clamp(arrive * 3) * 0.9,
                          child: Transform.translate(
                            offset: Offset(0, carY + 26),
                            child: Transform.scale(
                              scale: carScale,
                              child: Container(
                                width: 70,
                                height: 5,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.rectangle,
                                  borderRadius:
                                      BorderRadius.all(Radius.elliptical(35, 2.5)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x33142820),
                                      blurRadius: 5,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Opacity(
                          opacity: _clamp(arrive * 8),
                          child: Transform.translate(
                            offset: Offset(0, carY),
                            child: Transform.scale(
                              scale: carScale,
                              alignment: Alignment.bottomCenter,
                              child: CustomPaint(
                                size: const Size(78, 55),
                                painter: BonnetCarPainter(
                                  cutout: _green,
                                  fold: fold,
                                  lift: lift,
                                  rod: rod,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: -4,
                          bottom: 2,
                          child: Opacity(
                            opacity: _clamp(checkIn / 0.4),
                            child: Transform.scale(
                              scale: checkScale,
                              child: Container(
                                width: 44,
                                height: 44,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: _green, width: 2.5),
                                ),
                                child: CustomPaint(
                                  painter: CheckPainter(_green, checkDraw),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  // The same mark used everywhere else, driven through its
                  // entrance: the halves come together, the V draws itself.
                  Opacity(
                    opacity: _clamp(text),
                    child: BrandWordmark(
                      fontSize: 30,
                      checkScale: 1.4,
                      entrance: _clamp(text),
                      checkProgress: _clamp(text * 1.3),
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
