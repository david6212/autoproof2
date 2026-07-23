import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/auth_provider.dart';

/// Luxury AutoProof splash: deep-emerald gradient with a faint futuristic
/// grid, the brand shield inside a soft halo, an engraved-serif wordmark,
/// a gold subtitle, and a sleek loading bar. Fades in, then routes on.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  // Brand palette for this screen.
  static const _emeraldTop = Color(0xFF0F6E56);
  static const _emeraldDeep = Color(0xFF072A22);
  static const _gold = Color(0xFFD4AF37);

  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();

    // Switch to the main app after 2.5 seconds.
    _timer = Timer(const Duration(milliseconds: 2500), _goNext);
  }

  void _goNext() {
    if (!mounted) return;
    final user = ref.read(authRepositoryProvider).currentUser;
    context.go(user != null ? '/home' : '/onboarding');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_emeraldTop, _emeraldDeep],
          ),
        ),
        child: Stack(
          children: [
            // Faint futuristic grid + edge vignette.
            const Positioned.fill(
              child: CustomPaint(painter: _GridPainter()),
            ),
            // Centered brand block, fading + scaling in.
            Center(
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LogoWithHalo(),
                      const SizedBox(height: 28),
                      Text(
                        'AUTOPROOF',
                        style: GoogleFonts.cinzel(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Thin gold accent under the wordmark.
                      Container(
                        width: 54,
                        height: 2,
                        decoration: BoxDecoration(
                          color: _gold,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Sleek loading bar near the bottom.
            Positioned(
              left: 0,
              right: 0,
              bottom: 56,
              child: Center(
                child: FadeTransition(
                  opacity: _fade,
                  child: SizedBox(
                    width: 140,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: const LinearProgressIndicator(
                        minHeight: 3,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation(_gold),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The shield emblem inside a soft radial halo so its gold/silver details
/// stand out against the dark emerald background.
class _LogoWithHalo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.4, 1.0],
        ),
      ),
      alignment: Alignment.center,
      child: Image.asset(
        'assets/logo_emblem.png',
        width: 132,
        fit: BoxFit.contain,
      ),
    );
  }
}

/// Draws a subtle grid and a darkening vignette toward the edges.
class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;

    const gap = 42.0;
    for (double x = 0; x <= size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = 0; y <= size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }

    // Vignette: subtle dark radial gradient over the edges.
    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.28),
        ],
        stops: const [0.6, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), vignette);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
