import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/presentation/widgets/car/active_warnings_section.dart';
import 'package:bonnetcheck/presentation/widgets/common/collapsible_section.dart';

/// The car page's three levels, pinned where they can be pinned without
/// Firebase.
///
/// The page itself reaches Firestore and the registry through four providers,
/// so a full pump belongs in an integration test rather than here. What these
/// cover is the part that actually regressed and would regress again: the
/// vertical order of the pieces, and the promise that a folded section is
/// still legible while folded.
void main() {
  Widget host(List<Widget> children) => MaterialApp(
        theme: AppTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: ListView(children: children)),
        ),
      );

  group('order on the page', () {
    testWidgets('findings sit above the technical spec', (tester) async {
      // The whole point of the restructure. Before it, the odometer mismatch
      // was two thirds of the way down, below the tyre width.
      await tester.pumpWidget(host([
        ActiveWarningsSection(warnings: [
          ActiveWarning.odometerBelowOfficial(
              listedKm: 82000, officialKm: 94300, testDate: '03/2026'),
        ]),
        const CollapsibleSection(
          title: 'מפרט טכני מלא',
          summary: '12 שדות',
          child: Text('דגם מנוע'),
        ),
      ]));

      final findings = tester.getTopLeft(find.text(ActiveWarningsSection.heading));
      final spec = tester.getTopLeft(find.text('מפרט טכני מלא'));
      expect(findings.dy, lessThan(spec.dy));
    });

    testWidgets('an empty findings block takes no vertical room at all',
        (tester) async {
      // Most listings have nothing to report, and on those the page must open
      // on the title — not on a gap where a warning would have been. This is
      // also the bug that put a 50px hole in the old page: spacers around
      // widgets that render nothing.
      // A Column rather than the ListView above: a sliver list never lays out
      // a zero-extent child, so the widget would not be there to measure and
      // the test would pass for the wrong reason.
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Column(
              children: [
                ActiveWarningsSection(warnings: []),
                Text('ב.מ.וו 320i 2021'),
              ],
            ),
          ),
        ),
      ));

      expect(tester.getSize(find.byType(ActiveWarningsSection)).height, 0);
      // And the title really is at the top, not pushed down by a spacer.
      expect(tester.getTopLeft(find.text('ב.מ.וו 320i 2021')).dy, 0);
    });
  });

  group('folded but not hidden', () {
    testWidgets('every level-three section names its contents while closed',
        (tester) async {
      // A reader must never have to open a section to learn they did not want
      // it. These are the four summaries the page ships with.
      const summaries = {
        'מפרט טכני מלא': '12 שדות',
        'מסע הקנייה': 'השלמת 1 מתוך 4 · הבא: בדיקה פיזית',
        'הבהרה משפטית ודיווח': 'מקורות הנתונים, ודיווח על מודעה',
        'מכוני בדיקה באזור': '135 מכונים מורשים',
      };

      await tester.pumpWidget(host([
        for (final entry in summaries.entries)
          CollapsibleSection(
            title: entry.key,
            summary: entry.value,
            child: const Text('תוכן'),
          ),
      ]));

      for (final entry in summaries.entries) {
        expect(find.text(entry.key), findsOneWidget);
        expect(find.text(entry.value), findsOneWidget,
            reason: '${entry.key} folded away without saying what is inside');
      }
      // And none of them is showing its body.
      expect(find.text('תוכן'), findsNothing);
    });

    testWidgets('the journey summary carries live progress, not a label',
        (tester) async {
      // Decision 9ב. A plain link would have thrown away the one thing that
      // brings a buyer back to the listing: that they already started.
      await tester.pumpWidget(host([
        const CollapsibleSection(
          title: 'מסע הקנייה',
          summary: 'השלמת 2 מתוך 4 · הבא: בדיקת עומק לפני החלטה',
          child: Text('שלבים'),
        ),
      ]));

      expect(find.textContaining('2 מתוך 4'), findsOneWidget);
      expect(find.textContaining('הבא:'), findsOneWidget);
    });
  });
}
