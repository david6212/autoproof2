import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/presentation/widgets/buyer_journey_card.dart';

/// The closing step of the buyer journey now points at the state's own
/// ownership-transfer service, which since 2023 both sides can complete online
/// instead of queueing at the post office.
///
/// The thing worth guarding is not that the link exists — it is that it is
/// kept apart from the partner-report links. Those are documented as ready to
/// become affiliate links; a Ministry of Transport service must never end up
/// in that slot, because the entire argument of this app is that official data
/// and commercial claims are different things.
void main() {
  Widget host(Widget child, {double width = 390}) => ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SizedBox(
                width: width,
                child: SingleChildScrollView(child: child),
              ),
            ),
          ),
        ),
      );

  testWidgets('the journey renders without the official link crashing it',
      (tester) async {
    await tester.pumpWidget(host(const BuyerJourneyCard(carId: 'c1')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('מסע הקנייה'), findsOneWidget);
  });

  testWidgets('the closing step names what actually happens there',
      (tester) async {
    // It used to say only "קניתם את הרכב 🎉", which is the celebration and not
    // the task. Somebody at that step has a payment, a transfer and a handover
    // in front of them.
    await tester.pumpWidget(host(const BuyerJourneyCard(carId: 'c1')));
    await tester.pump();
    expect(find.text('סגירת הקנייה'), findsOneWidget);
    expect(find.textContaining('העברת בעלות'), findsWidgets);
  });

  testWidgets('an official service is marked as one, not as a partner',
      (tester) async {
    await tester.pumpWidget(host(const BuyerJourneyCard(carId: 'c1')));
    await tester.pump();

    // The source is named on the card. A reader deciding whether to trust a
    // link should not have to tap it to find out whose it is.
    expect(find.text('gov.il'), findsOneWidget);
  });

  testWidgets('it says what is needed before tapping', (tester) async {
    // Both sides identify and the seller pays the fee — the two facts that
    // decide whether this can be finished today or not at all.
    await tester.pumpWidget(host(const BuyerJourneyCard(carId: 'c1')));
    await tester.pump();
    expect(find.textContaining('זיהוי ממשלתי'), findsOneWidget);
    expect(find.textContaining('אפשר גם בדואר'), findsOneWidget);
  });

  testWidgets('the whole card still fits a narrow phone', (tester) async {
    await tester.pumpWidget(
      host(const BuyerJourneyCard(carId: 'c1'), width: 320),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
