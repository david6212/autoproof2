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
      );

  testWidgets('offers no way to delete or edit a record', (tester) async {
    await tester.pumpWidget(host(
      ServiceTimeline(records: [record()], onCorrect: (_) {}),
    ));

    expect(find.text('מחק'), findsNothing);
    expect(find.text('מחיקה'), findsNothing);
    expect(find.text('ערוך'), findsNothing);
    expect(find.text('עריכה'), findsNothing);
    expect(find.byIcon(Icons.delete), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });

  testWidgets('the only way to change it is to add a correction',
      (tester) async {
    ServiceRecord? asked;
    await tester.pumpWidget(host(
      ServiceTimeline(records: [record()], onCorrect: (r) => asked = r),
    ));

    await tester.tap(find.text('הוסף תיקון'));
    await tester.pump();
    expect(asked?.id, 's1');
  });

  testWidgets('a buyer gets the history with no way to write to it',
      (tester) async {
    // onCorrect null is the read-only view. A buyer reads the record; they do
    // not get an action that writes to someone else's car.
    await tester.pumpWidget(host(ServiceTimeline(records: [record()])));
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
    expect(
      find.textContaining('אינן ניתנות לעריכה או מחיקה'),
      findsOneWidget,
    );
  });

  testWidgets('an empty history renders nothing at all', (tester) async {
    await tester.pumpWidget(host(const ServiceTimeline(records: [])));
    expect(find.textContaining('אינן ניתנות'), findsNothing);
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
