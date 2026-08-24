import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/presentation/widgets/car/active_warnings_section.dart';

/// The findings block is the one part of the car page that can stop a
/// purchase, which makes it also the one part that can libel a seller. These
/// tests guard both edges: it has to show every number it has, and it must
/// never characterise them.
void main() {
  Widget host(List<ActiveWarning> warnings) => MaterialApp(
        theme: AppTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              child: ActiveWarningsSection(warnings: warnings),
            ),
          ),
        ),
      );

  /// Every string the section can put on screen, for the copy rules below.
  ///
  /// Five since 24/08: the sixth reported a disagreement between the seller's
  /// declared type and what buyers said they met, and the whole "who did you
  /// meet" feature was removed.
  List<ActiveWarning> allFive() => [
        ActiveWarning.odometerBelowOfficial(
            listedKm: 82000, officialKm: 94300, testDate: '03/2026'),
        ActiveWarning.odometerBelowPastListing(
            pastKm: 91000, currentKm: 82000, pastDate: '11/2025'),
        ActiveWarning.structuralChange(),
        ActiveWarning.openRecall(count: 1),
        ActiveWarning.offRoad(),
      ];

  String textOf(List<ActiveWarning> ws) =>
      ws.map((w) => '${w.title} ${w.detail}').join(' ');

  group('nothing to report', () {
    testWidgets('renders no widget at all when the list is empty',
        (tester) async {
      // Not a green tick, not "no problems found". Absence of a record is not
      // a clean bill of health, and drawing it as one is the most damaging
      // claim this app could make.
      await tester.pumpWidget(host(const []));

      expect(tester.getSize(find.byType(ActiveWarningsSection)).height, 0);
      expect(find.text(ActiveWarningsSection.heading), findsNothing);
    });
  });

  group('what the buyer sees', () {
    testWidgets('the odometer finding carries both numbers and the date',
        (tester) async {
      // A label like "mileage mismatch" is a conclusion. The two readings and
      // the date are the evidence, and they are what a buyer can take to the
      // seller.
      await tester.pumpWidget(host([
        ActiveWarning.odometerBelowOfficial(
            listedKm: 82000, officialKm: 94300, testDate: '03/2026'),
      ]));

      expect(find.textContaining('82,000'), findsOneWidget);
      expect(find.textContaining('94,300'), findsOneWidget);
      expect(find.textContaining('03/2026'), findsOneWidget);
    });

    testWidgets('all five findings render together', (tester) async {
      await tester.pumpWidget(host(allFive()));

      expect(tester.takeException(), isNull);
      expect(find.text(ActiveWarningsSection.heading), findsOneWidget);
      for (final w in allFive()) {
        expect(find.text(w.title), findsOneWidget, reason: w.id);
      }
    });

    testWidgets('an action is offered only when there is one', (tester) async {
      var tapped = false;
      await tester.pumpWidget(host([
        ActiveWarning.odometerBelowOfficial(
          listedKm: 82000,
          officialKm: 94300,
          testDate: '03/2026',
          actionLabel: 'הצג את המקור',
          onAction: () => tapped = true,
        ),
        ActiveWarning.structuralChange(),
      ]));

      expect(find.text('הצג את המקור'), findsOneWidget);
      await tester.tap(find.text('הצג את המקור'));
      expect(tapped, isTrue);
    });
  });

  group('the copy rules', () {
    test('no finding characterises what it found', () {
      // Each of these would be us reaching a conclusion we have no basis for.
      // A seller who mistyped a number and a seller who rolled the clock back
      // produce the identical record.
      const forbidden = [
        'זויף',
        'חשוד',
        'היזהר',
        'הונאה',
        'רמאות',
        'סכנה',
      ];
      final copy = textOf(allFive());

      for (final word in forbidden) {
        expect(copy.contains(word), isFalse, reason: 'found "$word"');
      }
    });

    test('no finding reassures either', () {
      // The mirror image, and the reason §6.6 exists: this widget must never
      // become the place where the app certifies a car.
      for (final word in ['מאושר', 'תקין', 'בטוח', 'נבדק ונמצא']) {
        expect(textOf(allFive()).contains(word), isFalse,
            reason: 'found "$word"');
      }
    });

    test('nothing shouts', () {
      // An exclamation mark turns a record into an alarm, and the reader
      // cannot un-hear it.
      expect(textOf(allFive()).contains('!'), isFalse);
    });

    test('severity is assigned, not uniform', () {
      // If everything were high, the ranking would carry no information and
      // the block would be a wall again.
      final severities = allFive().map((w) => w.severity).toSet();
      expect(severities.length, 2, reason: 'both levels should be in use');
    });

    test('ids are unique, so a finding can be dismissed or linked', () {
      final ids = allFive().map((w) => w.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });
}
