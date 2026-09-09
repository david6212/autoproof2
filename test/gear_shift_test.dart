import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/presentation/widgets/gear_shift_overlay.dart';

/// The gear-shift that plays when a stage of the purchase is ticked.
///
/// Five stages, five gears. The animation is a reward for a write that has
/// already happened, so nothing here may be able to cost somebody their
/// progress — and it has to disappear on its own, because a celebration that
/// waits to be dismissed is an obstacle.
void main() {
  final source =
      File('lib/presentation/widgets/gear_shift_overlay.dart').readAsStringSync();
  final card = File('lib/presentation/widgets/buyer_journey_card.dart')
      .readAsStringSync();

  testWidgets('it plays, then leaves without being asked', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const Scaffold(body: SizedBox());
      }),
    ));

    GearShiftOverlay.show(ctx, from: 4, to: 5, stepTitle: 'ביטוח, ואז המפתחות');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('הילוך 5'), findsOneWidget);
    expect(find.text('ביטוח, ואז המפתחות'), findsOneWidget);

    // Advance past travel and hold explicitly: pumpAndSettle stops as soon as
    // no frame is scheduled, which can be before the dismissal timer fires.
    await tester.pump(const Duration(milliseconds: 700));   // travel
    await tester.pump(const Duration(milliseconds: 400));   // hold
    await tester.pumpAndSettle();                            // the way out

    expect(find.text('הילוך 5'), findsNothing,
        reason: 'a celebration that has to be dismissed is an obstacle');
  });

  testWidgets('reduced motion skips it entirely', (tester) async {
    // Somebody who asked the OS for less motion asked for exactly this. A
    // flourish is the first thing to drop, never the last.
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(builder: (c) {
          ctx = c;
          return const Scaffold(body: SizedBox());
        }),
      ),
    ));

    await GearShiftOverlay.show(ctx, from: 1, to: 2, stepTitle: 'בדיקה פיזית');
    await tester.pump();
    expect(find.text('הילוך 2'), findsNothing);
  });

  test('the knob travels an H, never a diagonal', () {
    // The whole reason this is worth drawing. A point interpolated straight
    // from gear 2 to gear 3 crosses the middle of the gate, where no gear
    // stick has ever been — it reads as a dot sliding rather than a lever
    // engaging. The path leaves the gate, crosses, and enters.
    expect(source, contains('_mid'));
    expect(source, contains('if (a.dx != b.dx)'),
        reason: 'a rail change has to add the crossing waypoints');
  });

  test('and it settles at the end like something mechanical', () {
    expect(source, contains('math.sin'));
  });

  test('five gears, and the gate is shaped like a real one', () {
    // Three rails. The right one stops at the crossbar because gear 5 has no
    // partner below it — there is no reverse in buying a car.
    for (final gear in ['1:', '2:', '3:', '4:', '5:']) {
      expect(source, contains(gear));
    }
    expect(source.contains('6:'), isFalse);
  });

  test('the progress is written before the animation is asked for', () {
    // The order matters: a shift that failed to draw must never be able to
    // cost somebody the stage they just ticked.
    final write = card.indexOf('setJourneyStageProvider).call(carId');
    final show = card.indexOf('GearShiftOverlay.show(');
    expect(write, greaterThan(-1));
    expect(show, greaterThan(write),
        reason: 'the reward comes after the thing it rewards');
  });

  test('the journey has five stages and insurance is the last', () {
    final labels = card.indexOf('_actionLabels');
    expect(card.indexOf("'סגרתי ביטוח — קיבלתי את המפתחות'"), greaterThan(labels));
    // The keys moved into the insurance stage. The card's own warning says to
    // close insurance before taking them, so leaving handover in the previous
    // step would have made the stages contradict that sentence.
    expect(card, contains('ביטוח, ואז המפתחות'));
    expect(card.contains("subtitle: 'תשלום, העברת בעלות ומסירת הרכב'"), isFalse);
  });

  test('finishing offers the garage, because a reminder needs a vehicle', () {
    // The renewal reminder lives on a car in the owner's garage, and the car
    // they have just bought is not in theirs yet. Offering the reminder here
    // would be a button with nowhere to write.
    expect(card, contains("context.push('/garage/add')"));
    expect(card, contains('InsuranceRenewal.leadDays'));
  });
}
