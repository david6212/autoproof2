// The splash is the first thing every user sees, so a crash in it is fatal.
// easeOutBack deliberately overshoots past 1, and Opacity throws outside
// 0..1 — every stage clamps, and this walks the whole intro to prove it.
//
// The look of the animation is not testable here. That still needs eyes.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:otov/presentation/screens/auth/splash_screen.dart';

void main() {
  testWidgets('plays the whole intro without throwing', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SplashScreen()),
      ),
    );

    // The intro runs 1400ms; step through it finely enough to land inside
    // every stage, including the overshoot at the end of each.
    for (var t = 0; t <= 1600; t += 50) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull, reason: 'threw at ${t}ms');
    }

    // Tear down before the hold timer routes away — there is no router here.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the car and the check approach from opposite sides',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SplashScreen()),
      ),
    );

    // Mid-travel: both are in flight, on either side of where they land.
    await tester.pump(const Duration(milliseconds: 600));

    final dxs = tester
        .widgetList<Transform>(find.byType(Transform))
        .map((t) => t.transform.getTranslation().x)
        .where((x) => x.abs() > 1)
        .toList();

    expect(dxs.length, greaterThanOrEqualTo(2),
        reason: 'expected the car and the check to both be travelling');
    expect(dxs.any((x) => x < 0), isTrue, reason: 'nothing came from the left');
    expect(dxs.any((x) => x > 0), isTrue, reason: 'nothing came from the right');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('they have met by the time the intro ends', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SplashScreen()),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1400));

    final dxs = tester
        .widgetList<Transform>(find.byType(Transform))
        .map((t) => t.transform.getTranslation().x)
        .toList();

    // Everything has settled onto its resting x.
    for (final dx in dxs) {
      expect(dx.abs(), lessThan(1.0));
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
