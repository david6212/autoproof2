import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The gear-shift that plays when a buyer ticks off a stage of the purchase.
///
/// Five stages, five gears — and a five-speed gate is the commonest one on the
/// road here, so the shape is recognised before the animation is read.
///
/// **The knob never travels in a straight line.** A real shift leaves the gate,
/// crosses, and enters the new one, so the path is a set of waypoints along an
/// H rather than an interpolation between two points. A dot sliding diagonally
/// across a gate is the difference between an animation and an object, and it
/// is the whole reason this is worth drawing at all.
///
/// The gate is graphite in both themes on purpose. It is a machined part, not a
/// surface — metal does not turn white in the light theme — and keeping it dark
/// leaves the engaged gear as the only saturated thing on screen. Everything
/// around it (the scrim, the text) still comes from the theme.
class GearShiftOverlay {
  GearShiftOverlay._();

  static const _enter = Duration(milliseconds: 170);
  static const _travel = Duration(milliseconds: 560);
  static const _hold = Duration(milliseconds: 360);

  /// Plays the shift from [from] to [to], then dismisses itself.
  ///
  /// Returns as soon as it is gone, so a caller can await it before doing
  /// anything that would draw over the top.
  static Future<void> show(
    BuildContext context, {
    required int from,
    required int to,
    required String stepTitle,
  }) {
    // Somebody who has asked the OS to reduce motion has asked for this
    // exactly. A celebration is the first thing to drop, not the last.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return Future<void>.value();
    }

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'מעבר הילוך',
      barrierColor: Colors.black.withValues(alpha: 0.28),
      transitionDuration: _enter,
      pageBuilder: (_, __, ___) =>
          _GearShiftDialog(from: from, to: to, stepTitle: stepTitle),
      transitionBuilder: (_, anim, __, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween(begin: 0.88, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GearShiftDialog extends StatefulWidget {
  const _GearShiftDialog({
    required this.from,
    required this.to,
    required this.stepTitle,
  });

  final int from;
  final int to;
  final String stepTitle;

  @override
  State<_GearShiftDialog> createState() => _GearShiftDialogState();
}

class _GearShiftDialogState extends State<_GearShiftDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: GearShiftOverlay._travel,
  );

  @override
  void initState() {
    super.initState();
    _c.forward().then((_) async {
      await Future<void>.delayed(GearShiftOverlay._hold);
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: const Color(0xFF2B3230),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 136,
                height: 136,
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) => CustomPaint(
                    painter: _GatePainter(
                      from: widget.from,
                      to: widget.to,
                      t: _c.value,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'הילוך ${widget.to}',
                style: const TextStyle(
                  // Latin digits in Poppins, the same rule the wordmark
                  // follows. Heebo carries the Hebrew beside it.
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.stepTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF9FB0A8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws a five-speed gate and the knob part-way through a shift.
class _GatePainter extends CustomPainter {
  _GatePainter({required this.from, required this.to, required this.t});

  final int from;
  final int to;

  /// 0 to 1 through the travel.
  final double t;

  /// Gear positions in a unit box. Three rails: 1 and 2 on the near one, 3 and
  /// 4 on the middle, 5 alone on the far one — which is why the right rail
  /// stops at the crossbar. There is no reverse in buying a car.
  static const _gears = <int, Offset>{
    1: Offset(0.25, 0.24),
    2: Offset(0.25, 0.76),
    3: Offset(0.50, 0.24),
    4: Offset(0.50, 0.76),
    5: Offset(0.75, 0.24),
  };
  static const _mid = 0.50;

  static const _slot = Color(0xFF0F1312);
  static const _edge = Color(0xFF4A554F);
  static const _label = Color(0xFF8FA096);
  static const _knob = Color(0xFF202624);
  static const _knobEdge = Color(0xFF5C6B64);
  static const _engaged = Color(0xFF1E6B45); // tealFill: the app's own green

  /// Out of the gate, across if the rail changes, then in. Never a straight
  /// line between two gears.
  static List<Offset> _path(int from, int to) {
    final a = _gears[from]!, b = _gears[to]!;
    final pts = <Offset>[a];
    if (a.dx != b.dx) {
      pts.add(Offset(a.dx, _mid));
      pts.add(Offset(b.dx, _mid));
    }
    pts.add(b);
    return pts;
  }

  Offset _positionAt(double e) {
    final pts = _path(from, to);
    final segs = pts.length - 1;
    final pos = (e * segs).clamp(0.0, segs.toDouble());
    final i = math.min(segs - 1, pos.floor());
    final f = pos - i;
    final p0 = pts[i], p1 = pts[i + 1];
    var p = Offset(
      p0.dx + (p1.dx - p0.dx) * f,
      p0.dy + (p1.dy - p0.dy) * f,
    );

    // A touch past the gate and back, in the direction of travel: the settle
    // of something mechanical catching. Without it the knob simply stops, and
    // stopping is what a value does, not what a lever does.
    if (e > 0.82) {
      final k = math.sin((e - 0.82) / 0.18 * math.pi) * 0.032;
      final d = p1 - p0;
      final len = d.distance == 0 ? 1.0 : d.distance;
      p += Offset(d.dx / len * k, d.dy / len * k);
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    Offset u(Offset o) => Offset(o.dx * size.width, o.dy * size.height);

    final rails = Path()
      ..moveTo(0.25 * size.width, 0.24 * size.height)
      ..lineTo(0.25 * size.width, 0.76 * size.height)
      ..moveTo(0.50 * size.width, 0.24 * size.height)
      ..lineTo(0.50 * size.width, 0.76 * size.height)
      ..moveTo(0.75 * size.width, 0.24 * size.height)
      ..lineTo(0.75 * size.width, 0.50 * size.height)
      ..moveTo(0.25 * size.width, 0.50 * size.height)
      ..lineTo(0.75 * size.width, 0.50 * size.height);

    canvas.drawPath(
      rails,
      Paint()
        ..color = _slot
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.085
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      rails,
      Paint()
        ..color = _edge.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.02
        ..strokeCap = StrokeCap.round,
    );

    for (final entry in _gears.entries) {
      final top = entry.value.dy < _mid;
      final tp = TextPainter(
        text: TextSpan(
          text: '${entry.key}',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: entry.key == to ? _engaged : _label,
            fontSize: size.width * 0.095,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final c = u(entry.value);
      tp.paint(
        canvas,
        Offset(
          c.dx - tp.width / 2,
          top ? c.dy - size.height * 0.13 - tp.height : c.dy + size.height * 0.07,
        ),
      );
    }

    final eased = Curves.easeInOutCubic.transform(t);
    final knob = u(_positionAt(eased));
    final r = size.width * 0.075;

    canvas.drawCircle(knob, r, Paint()..color = _knob);
    canvas.drawCircle(
      knob,
      r,
      Paint()
        ..color = _knobEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(knob, r * 0.42, Paint()..color = _engaged);
  }

  @override
  bool shouldRepaint(_GatePainter old) =>
      old.t != t || old.from != from || old.to != to;
}
