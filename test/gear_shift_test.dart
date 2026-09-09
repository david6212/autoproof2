import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/presentation/providers/cars_provider.dart';
import 'package:bonnetcheck/presentation/widgets/buyer_journey_card.dart';
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

  test('the gear equals the stages completed, not one ahead', () {
    // The journey opens on gear 1 — reading the registry happens simply by
    // opening the listing — so ticking the step at index i moves from i to
    // i+1. The first version animated i+1 to i+2 and showed the wrong gear on
    // every single shift, which is invisible in a test that only checks the
    // overlay appears.
    expect(card, contains('from: fromIndex, to: fromIndex + 1'));
    expect(card.contains('from: fromIndex + 1, to: fromIndex + 2'), isFalse);
  });

  testWidgets('the undo is visible the way the app actually renders the card',
      (tester) async {
    // **The test that was missing, and it cost a shipped build.** The control
    // spent one release in `AppSectionCard`'s header — and the only call site
    // in the app passes `collapsible: true`, so that whole branch is dead code.
    // The compiler dropped the button's label string from the binary entirely.
    //
    // A source scan cannot see this: the code is right there in the file. Only
    // rendering it the way the app does can.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        // Stage 3, because at stage 1 there is correctly nothing to undo —
        // reading the registry happens by opening the listing, and it is not
        // something the reader did.
        journeyStageProvider('c1').overrideWith((ref) => Stream.value(3)),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              child: BuyerJourneyCard(carId: 'c1', collapsible: true),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    // The card is a fold and opens closed, so open it the way a reader does.
    await tester.tap(find.text('מסע הקנייה'));
    await tester.pumpAndSettle();

    expect(find.text('חזרה שלב אחורה'), findsOneWidget,
        reason: 'a rendered control, not one in a branch nobody reaches');
  });

  test('a stage can be un-ticked, one at a time', () {
    // Somebody who mis-tapped wants the tap undone, not the journey erased.
    // This replaced an "אפס" that only appeared once the journey was finished
    // and threw all of it away.
    expect(card, contains('_stepBack('));
    expect(card, contains('חזרה שלב אחורה'));
    expect(card.contains("child: const Text('אפס'"), isFalse);
    // And going back is guarded the same way going forward is.
    final back = card.indexOf('void _stepBack(');
    final guard = card.indexOf('showLoginRequired', back);
    final write = card.indexOf('setJourneyStageProvider', back);
    expect(guard, lessThan(write),
        reason: 'a guest is asked to sign in before anything is written');
  });

  test('finishing offers the garage, because a reminder needs a vehicle', () {
    // The renewal reminder lives on a car in the owner's garage, and the car
    // they have just bought is not in theirs yet. Offering the reminder here
    // would be a button with nowhere to write.
    expect(card, contains("context.push('/garage/add')"));
    expect(card, contains('InsuranceRenewal.leadDays'));
  });
}
