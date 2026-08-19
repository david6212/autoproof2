import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/data/models/vehicle.dart';
import 'package:bonnetcheck/presentation/widgets/documented_progress_meter.dart';

/// The badge is the only thing that persuades an owner to log the first
/// service, and until now it was invisible until the moment it was earned —
/// two records and one month away looked identical to never having started.
///
/// These pin the meter that replaced that, and mostly they pin its honesty:
/// it may encourage, it may not flatter. A buyer's reason to believe "תיק
/// מתועד" is that it cannot be performed, and everything here is upstream of
/// that promise.
void main() {
  Vehicle vehicle({required int count, required int spanDays}) => Vehicle(
        id: 'v1',
        plate: '88888888',
        ownerId: 'u1',
        serviceCount: count,
        firstServiceAt: count == 0 ? null : DateTime(2025, 1, 1),
        lastServiceAt:
            count == 0 ? null : DateTime(2025, 1, 1).add(Duration(days: spanDays)),
        createdAt: DateTime(2025, 1, 1),
      );

  Widget host(Widget child, {double width = 390}) => MaterialApp(
        theme: AppTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: SingleChildScrollView(child: child),
              ),
            ),
          ),
        ),
      );

  group('the arithmetic', () {
    test('the badge rule and the meter read the same two numbers', () {
      // They did not always: the progress line carried its own literal 3 and
      // 6 beside the rule, so changing the rule would have changed only half
      // the app.
      final earned = vehicle(count: 3, spanDays: 200).documentedProgress;

      expect(Vehicle.documentedMinRecords, 3);
      expect(Vehicle.documentedMinMonths, 6);
      expect(earned.earned, isTrue);
      expect(vehicle(count: 3, spanDays: 200).hasDocumentedHistory, isTrue);
    });

    test('the bar tracks the half that is further behind', () {
      // Six receipts entered in one week is a full count with no span. An
      // average would read 50% and tell the owner they are halfway, when the
      // badge is as far off as it was before.
      final crammed = vehicle(count: 6, spanDays: 7).documentedProgress;

      expect(crammed.records, 6);
      expect(crammed.months, 0);
      expect(crammed.fraction, 0);
      expect(crammed.earned, isFalse);
    });

    test('progress never exceeds full, and never goes negative', () {
      final over = vehicle(count: 9, spanDays: 900).documentedProgress;
      expect(over.fraction, 1);
      expect(over.recordsNeeded, 0);
      expect(over.monthsNeeded, 0);

      final none = vehicle(count: 0, spanDays: 0).documentedProgress;
      expect(none.fraction, 0);
      expect(none.started, isFalse);
    });

    test('what is left is counted, not estimated', () {
      final p = vehicle(count: 1, spanDays: 60).documentedProgress;
      expect(p.records, 1);
      expect(p.months, 2);
      expect(p.recordsNeeded, 2);
      expect(p.monthsNeeded, 4);
    });
  });

  group('what the owner reads', () {
    testWidgets('leads with what is done, not with what is missing',
        (tester) async {
      await tester.pumpWidget(host(DocumentedProgressMeter(
        progress: vehicle(count: 2, spanDays: 120).documentedProgress,
      )));

      // The counts, phrased as achievement.
      expect(find.textContaining('2 מתוך 3 רשומות'), findsOneWidget);
      expect(find.textContaining('4 מתוך 6 חודשים'), findsOneWidget);
      // The deficit survives as a closing line — an owner with the records but
      // not the span needs to learn that only time will finish it.
      expect(find.textContaining('נותרו'), findsOneWidget);
      // And never the old framing, which opened on the shortfall.
      expect(find.textContaining('חסרים'), findsNothing);
    });

    testWidgets('says nothing before the first record', (tester) async {
      // The empty state already explains what the badge is for. A meter
      // reading zero would add a second, weaker version of that — and an
      // owner who has logged nothing has no progress to be reminded of.
      await tester.pumpWidget(host(DocumentedProgressMeter(
        progress: vehicle(count: 0, spanDays: 0).documentedProgress,
      )));

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(
        tester.getSize(find.byType(DocumentedProgressMeter)).height,
        0,
        reason: 'must leave no gap in the list it sits in',
      );
    });

    testWidgets('disappears once the badge is earned', (tester) async {
      // From here the car wears "תיק מתועד" itself; a progress bar pinned at
      // full beside it would be noise.
      await tester.pumpWidget(host(DocumentedProgressMeter(
        progress: vehicle(count: 4, spanDays: 400).documentedProgress,
      )));

      expect(tester.getSize(find.byType(DocumentedProgressMeter)).height, 0);
    });

    testWidgets('the compact form fits a garage card without overflowing',
        (tester) async {
      // The garage card is the narrowest place this appears, and the line
      // carries both counts. 320 is the smallest phone we lay out for.
      await tester.pumpWidget(host(
        DocumentedProgressMeter(
          progress: vehicle(count: 2, spanDays: 120).documentedProgress,
          compact: true,
        ),
        width: 320 - 32, // card padding on both sides
      ));

      expect(tester.takeException(), isNull);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });
}
