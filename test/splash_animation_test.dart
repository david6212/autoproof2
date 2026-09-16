// The splash is the first thing every user sees, so a crash in it is fatal.
// Back-out curves deliberately overshoot past 1, and Opacity throws outside
// 0..1 — every beat clamps, and this walks the whole intro to prove it.
//
// Whether it looks like a car opening its bonnet is not testable here. That
// was judged by eye, on the sketch, before this was built.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/presentation/screens/auth/splash_screen.dart';
import 'package:bonnetcheck/presentation/widgets/bonnet_car_painter.dart';

void main() {
  Widget app({bool reduceMotion = false}) => ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduceMotion),
            child: const SplashScreen(),
          ),
        ),
      );

  BonnetCarPainter car(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((p) => p.painter)
      .whereType<BonnetCarPainter>()
      .single;

  double carScale(WidgetTester tester) {
    final paint = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is BonnetCarPainter);
    // The Transform wrapping the painter directly is the scale; the one
    // outside it only moves the car up and down.
    final scale = tester
        .widgetList<Transform>(
            find.ancestor(of: paint, matching: find.byType(Transform)))
        .firstWhere((t) => t.child is CustomPaint);
    // Not getMaxScaleOnAxis: Transform.scale leaves z at 1, so that is 1 always.
    return scale.transform.entry(0, 0);
  }

  testWidgets('plays the whole intro without throwing', (tester) async {
    await tester.pumpWidget(app());

    // Step finely enough to land inside every beat, overshoots included.
    for (var t = 0; t <= 3200; t += 25) {
      await tester.pump(const Duration(milliseconds: 25));
      expect(tester.takeException(), isNull, reason: 'threw at ${t}ms');
    }

    // Tear down before the hold timer routes away — there is no router here.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the car comes from far away', (tester) async {
    await tester.pumpWidget(app());

    // Most of the approach it is still small — apparent size goes as
    // 1 / distance, so a car that grew evenly would look like it slid in.
    await tester.pump(const Duration(milliseconds: 600));
    final early = carScale(tester);
    expect(early, lessThan(0.25), reason: 'already close at 600ms');

    await tester.pump(const Duration(milliseconds: 700)); // 1300ms
    expect(carScale(tester), closeTo(1.0, 0.001), reason: 'has not arrived');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the bonnet is shut while it drives, open once it stops',
      (tester) async {
    await tester.pumpWidget(app());

    await tester.pump(const Duration(milliseconds: 900));
    expect(car(tester).fold, 0, reason: 'bonnet opened on the move');
    expect(car(tester).lift, 0);

    await tester.pump(const Duration(milliseconds: 1300)); // 2200ms
    expect(car(tester).fold, 1);
    expect(car(tester).lift, closeTo(1.0, 0.001));
    expect(car(tester).rod, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the name assembles from opposite sides, after the bonnet',
      (tester) async {
    await tester.pumpWidget(app());

    // Its own window is 2350–3050ms.
    await tester.pump(const Duration(milliseconds: 2700));

    final dxs = tester
        .widgetList<Transform>(find.byType(Transform))
        .map((t) => t.transform.getTranslation().x)
        .where((x) => x.abs() > 1)
        .toList();

    expect(dxs.any((x) => x < 0), isTrue,
        reason: '"Bonnet" should still be coming in from the left');
    expect(dxs.any((x) => x > 0), isTrue,
        reason: 'the V should still be coming in from the right');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('everything has landed by the time the intro ends',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 3100));

    for (final t in tester.widgetList<Transform>(find.byType(Transform))) {
      expect(t.transform.getTranslation().x.abs(), lessThan(1.0));
    }
    expect(carScale(tester), closeTo(1.0, 0.001));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reduce motion: the finished mark, no car driving in',
      (tester) async {
    await tester.pumpWidget(app(reduceMotion: true));
    await tester.pump();

    expect(carScale(tester), closeTo(1.0, 0.001));
    expect(car(tester).lift, closeTo(1.0, 0.001));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('the logo everywhere else keeps the photograph', () {
    // Only the splash draws the car. The brand mark elsewhere is the picture,
    // and must stay the picture.
    final logo =
        File('lib/presentation/widgets/brand_logo.dart').readAsStringSync();
    expect(logo, contains("'assets/layers/car.png'"));
  });
}
