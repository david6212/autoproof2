import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/data/models/service_record.dart';
import 'package:bonnetcheck/presentation/widgets/service_timeline.dart';

/// The append-only rule is enforced in three places — the security rules, the
/// repository, and the UI. The first two are invisible to a user; this one is
/// the one they actually experience, so it is the one worth pinning. If a
/// later change adds a delete or edit action here, the history stops being
/// evidence and these tests should fail loudly.
void main() {
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

  ServiceRecord record({
    String id = 's1',
    String title = 'טיפול 60,000',
    int km = 60000,
    int cost = 1200,
    String? corrects,
    String? receiptUrl,
      DateTime? editedAt,
  }) =>
      ServiceRecord(
        id: id,
        type: ServiceType.routine,
        title: title,
        date: DateTime(2026, 3, 4),
        km: km,
        cost: cost,
        addedByOwnerId: 'u1',
        createdAt: DateTime(2026, 3, 4),
        correctsServiceId: corrects,
        receiptUrl: receiptUrl,
        editedAt: editedAt,
      );

  testWidgets('the owner may edit a record, and never delete one',
      (tester) async {
    // Editing arrived 25/08 on David's instruction. Deletion did not, and the
    // difference is the point: fixing a wrong figure leaves a history, erasing
    // an inconvenient service does not.
    await tester.pumpWidget(host(
      ServiceTimeline(records: [record()], onEdit: (_) {}),
    ));

    expect(find.text('ערוך'), findsOneWidget);
    expect(find.text('מחק'), findsNothing);
    expect(find.text('מחיקה'), findsNothing);
    expect(find.byIcon(Icons.delete), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('the edit action hands back the record it belongs to',
      (tester) async {
    ServiceRecord? asked;
    await tester.pumpWidget(host(
      ServiceTimeline(records: [record()], onEdit: (r) => asked = r),
    ));

    await tester.tap(find.text('ערוך'));
    await tester.pump();
    expect(asked?.id, 's1');
  });

  testWidgets('an edited record says so, with the date', (tester) async {
    // The price of an editable history. Without this the list would be a log
    // that quietly rewrote itself while still being shown to buyers as
    // evidence.
    await tester.pumpWidget(host(ServiceTimeline(
      records: [record(editedAt: DateTime(2026, 8, 25))],
    )));

    expect(find.textContaining('עודכנה ב-'), findsOneWidget);
  });

  testWidgets('a record nobody touched carries no edit mark', (tester) async {
    await tester.pumpWidget(host(ServiceTimeline(records: [record()])));
    // The dated form, not the bare word: the footer explains that an edited
    // record is marked, and would match a looser search.
    expect(find.textContaining('עודכנה ב-'), findsNothing);
  });

  testWidgets('a buyer gets the history with no way to write to it',
      (tester) async {
    // onEdit null is the read-only view. A buyer reads the record; they do
    // not get an action that writes to someone else's car.
    await tester.pumpWidget(host(ServiceTimeline(records: [record()])));
    expect(find.text('ערוך'), findsNothing);
    expect(find.text('הוסף תיקון'), findsNothing);
    expect(find.text('טיפול 60,000'), findsOneWidget);
  });

  testWidgets('both sides of a correction are labelled', (tester) async {
    await tester.pumpWidget(host(
      ServiceTimeline(
        records: [
          record(id: 's2', title: 'תיקון ק"מ', corrects: 's1'),
          record(id: 's1'),
        ],
      ),
    ));

    // The correction says what it is, and the original says it was corrected —
    // otherwise a reader sees two contradictory entries and no explanation.
    expect(find.text('תיקון לרשומה קודמת'), findsOneWidget);
    expect(find.text('נוסף תיקון לרשומה זו'), findsOneWidget);
  });

  testWidgets('an uncorrected record carries neither tag', (tester) async {
    await tester.pumpWidget(host(ServiceTimeline(records: [record()])));
    expect(find.text('תיקון לרשומה קודמת'), findsNothing);
    expect(find.text('נוסף תיקון לרשומה זו'), findsNothing);
  });

  testWidgets('states plainly that the records were not verified by us',
      (tester) async {
    await tester.pumpWidget(host(ServiceTimeline(records: [record()])));
    // The claims rule: the app never vouches for what an owner typed.
    expect(
      find.textContaining('לא אומתו על ידי BonnetCheck'),
      findsOneWidget,
    );
    // Records became editable, so the footer had to stop saying they are not.
    // What it says instead is the two things that are still true.
    expect(find.textContaining('מחיקה אינה אפשרית'), findsOneWidget);
    expect(find.textContaining('רשומה שעודכנה מסומנת'), findsOneWidget);
  });

  testWidgets('an empty history renders nothing at all', (tester) async {
    await tester.pumpWidget(host(const ServiceTimeline(records: [])));
    expect(find.textContaining('מחיקה אינה אפשרית'), findsNothing);
  });

  testWidgets('a receipt is offered only when one exists', (tester) async {
    await tester.pumpWidget(host(ServiceTimeline(records: [record()])));
    expect(find.text('קבלה'), findsNothing);

    await tester.pumpWidget(host(ServiceTimeline(
      records: [record(receiptUrl: 'https://example.test/r.jpg')],
    )));
    expect(find.text('קבלה'), findsOneWidget);
  });
}
