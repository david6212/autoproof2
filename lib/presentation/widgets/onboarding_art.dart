import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';

/// The pictures on the three opening screens.
///
/// Each one draws the thing its slide is talking about, rather than a symbol
/// standing in for it: a licence plate being read, two mileage figures that
/// disagree, a stack of dated service records. A magnifying-glass icon says
/// "search"; a plate with digits on it says "type your plate and we will look
/// it up", which is the actual promise.
///
/// Built from Flutter widgets rather than shipped as image files, for three
/// reasons: they follow the light and dark palettes without a second asset,
/// they stay sharp at any pixel density, and they add nothing to the download.
/// A PNG would have to be produced twice and would still be soft on a tall
/// phone.
class OnboardingArt extends StatelessWidget {
  const OnboardingArt({super.key, required this.index});

  final int index;

  static const _size = 168.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      // scaleDown, not a bigger _size. Slide one already stood 173px tall in
      // a 168px box and clipped its own bottom edge on a 360x780 phone — but
      // raising the number only moves the cliff. These drawings are built
      // from text and icons, so they grow with the reader's font setting, and
      // somebody running Android's largest text size overflows by far more
      // than five pixels. Shrinking to fit answers every size at once, and
      // costs nothing at the default one, where nothing is scaled.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: switch (index) {
          0 => const _PlateLookup(),
          1 => const _Mismatch(),
          _ => const _Passport(),
        },
      ),
    );
  }
}

/// Slide 1 — an Israeli plate, and the record that comes back for it.
class _PlateLookup extends StatelessWidget {
  const _PlateLookup();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The yellow is the plate's own, not a palette colour: an Israeli
        // plate is recognisable before a single digit is read, and that
        // recognition is the whole point of drawing one.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFF2C438),
            borderRadius: BorderRadius.circular(AppRadius.xs + 2),
            border: Border.all(color: const Color(0xFF2B2B2B), width: 2),
          ),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '12-345-67',
              style: TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                height: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Icon(Icons.keyboard_double_arrow_down_rounded,
            size: 22, color: colors.teal),
        const SizedBox(height: AppSpace.sm),
        // Three answers coming back. Deliberately unreadable at this size —
        // it is a shape of a result, not a result.
        Container(
          width: 132,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.md, vertical: AppSpace.sm),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: colors.cardBorder),
          ),
          child: Column(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(height: 7),
                Row(
                  children: [
                    Icon(Icons.check_rounded, size: 13, color: colors.teal),
                    const SizedBox(width: 6),
                    Expanded(child: _Bar(width: [1.0, .72, .86][i])),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Slide 2 — the odometer finding, which is the app's signature check.
class _Mismatch extends StatelessWidget {
  const _Mismatch();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Widget figure(String label, String value, Color ink, Color wash) {
      return Container(
        width: 150,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md, vertical: AppSpace.sm),
        decoration: BoxDecoration(
          color: wash,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 11, color: ink, height: 1.3)),
            ),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ink,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        figure('בטסט האחרון', '94,300', colors.textPrimary, colors.surface),
        const SizedBox(height: AppSpace.sm),
        // The listing claims less than the state recorded. Amber, not red:
        // a seller who typed a number wrong and a seller who rolled a clock
        // back produce the identical record, and the app cannot tell them
        // apart — the same rule the real warning copy follows.
        figure('במודעה', '82,000', colors.warnText, colors.warnBg),
        const SizedBox(height: AppSpace.md),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.priority_high_rounded, size: 15, color: colors.warnText),
            const SizedBox(width: 5),
            Text(
              'אי-התאמה',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: colors.warnText,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Slide 3 — the vehicle's own file: dated entries, stacking up.
class _Passport extends StatelessWidget {
  const _Passport();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Widget entry(IconData icon, double barWidth, {bool faded = false}) {
      return Container(
        width: 148,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.sm + 2, vertical: AppSpace.sm),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: colors.cardBorder),
        ),
        child: Opacity(
          opacity: faded ? .55 : 1,
          child: Row(
            children: [
              Icon(icon, size: 15, color: colors.teal),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Bar(width: barWidth),
                    const SizedBox(height: 5),
                    _Bar(width: barWidth * .55, faint: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        entry(Icons.build_outlined, 1.0),
        const SizedBox(height: 7),
        entry(Icons.tire_repair_outlined, .84),
        const SizedBox(height: 7),
        entry(Icons.local_gas_station_outlined, .92, faded: true),
        const SizedBox(height: AppSpace.md),
        // The badge a buyer sees on the listing when the file is real. It is
        // the reason to keep one, so it belongs in the picture.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colors.tealLight,
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: Text(
            'תיק מתועד',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.tealText,
            ),
          ),
        ),
      ],
    );
  }
}

/// A line of stand-in text. Never lorem: at this size real words would be
/// unreadable, and unreadable words look like a rendering fault.
class _Bar extends StatelessWidget {
  const _Bar({required this.width, this.faint = false});

  final double width;
  final bool faint;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: width,
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          color: faint
              ? context.colors.cardBorder
              : context.colors.teal.withValues(alpha: .35),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
