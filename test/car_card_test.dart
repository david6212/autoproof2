import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:otov/app/theme.dart';
import 'package:otov/core/theme/app_palette.dart';
import 'package:otov/data/models/car_model.dart';
import 'package:otov/presentation/widgets/car_card_widget.dart';

/// The card's height is not laid out — it is *computed* by
/// [CarCard.heightFor], because the grid on a wide window has to size a cell
/// before the card exists. That makes it a promise the card has to keep, and a
/// promise nothing else in the suite was checking.
///
/// Stacking the price onto its own line added a line of text, so the number
/// changed. These tests exist so the next change to that layout cannot quietly
/// leave the formula behind: an under-estimate overflows the cell, and Flutter
/// reports that as a render error rather than a wrong-looking card.
void main() {
  CarModel car({String title = 'מאזדה CX-5', int reviews = 0}) => CarModel(
        id: 'c1',
        plate: '88888888',
        make: title,
        model: '',
        year: 2019,
        price: 132000,
        km: 92000,
        hand: 2,
        area: 'תל אביב',
        sellerId: 's1',
        status: CarStatus.active,
        photos: const [],
        reasonForSelling: '',
        createdAt: DateTime(2026, 1, 1),
        reviewCount: reviews,
      );

  Widget host(CarModel c, {double textScale = 1.0, double width = 390}) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: Builder(
                  builder: (context) => SizedBox(
                    // Exactly the promise — no slack to hide an error in.
                    height: CarCard.heightFor(context),
                    child: CarCard(car: c, onTap: () {}, onToggleSave: () {}),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('fits the height it claims', (t) async {
    await t.pumpWidget(host(car()));
    expect(pendingError(t), isNull);
  });

  testWidgets('still fits at the largest text scale the app supports',
      (t) async {
    // The formula multiplies only the text lines by the scale; if a fixed gap
    // were accidentally scaled in, or a text line left out, this is where it
    // shows up.
    for (final scale in [1.0, 1.3, 1.6]) {
      await t.pumpWidget(host(car(), textScale: scale));
      expect(pendingError(t), isNull, reason: 'text scale $scale');
    }
  });

  testWidgets('a long title is ellipsised rather than pushing the price out',
      (t) async {
    await t.pumpWidget(host(car(title: 'מאזדה CX-5 סקייאקטיב פרימיום פלוס')));
    expect(pendingError(t), isNull);

    // The price is on its own line now, so it survives a title long enough to
    // have squeezed it out of the old shared row.
    expect(find.text('₪132,000'), findsOneWidget);
  });

  testWidgets('the meta line uses ink that clears 4.5:1 on the card', (t) async {
    // A design reference had this line in `textSubtle`, which measures 4.23:1
    // on white — fine for the incidental print it is meant for, under the
    // floor for four facts a buyer reads off a listing. `palette_test` pins
    // subtle at only 3.0, so nothing there would have caught the swap.
    double ratio(Color a, Color b) {
      final (x, y) = (a.computeLuminance(), b.computeLuminance());
      final (hi, lo) = x > y ? (x, y) : (y, x);
      return (hi + 0.05) / (lo + 0.05);
    }

    await t.pumpWidget(host(car()));
    final style = t.widget<Text>(find.textContaining('ק"מ')).style!;
    for (final p in [AppPalette.light, AppPalette.dark]) {
      expect(style.color, isNot(p.textSubtle),
          reason: 'the meta line must not use textSubtle');
    }
    expect(ratio(style.color!, AppPalette.light.surface), greaterThan(4.5));
  });

  testWidgets('the seller badge and the review chip do not share a corner',
      (t) async {
    // Both used to be pinned to the bottom of the photo; the badge moved down
    // from the top corner, so this is the collision to watch.
    await t.pumpWidget(host(car(reviews: 3), width: 320));
    expect(pendingError(t), isNull);

    final badge = t.getRect(find.text('בעלים פרטי'));
    final chip = t.getRect(find.text('3 חוות דעת'));
    expect(badge.overlaps(chip), isFalse,
        reason: 'badge $badge overlaps review chip $chip');
  });
}

/// `takeException` clears the pending error, so it must be read exactly once
/// per pump. Wrapping it keeps that intent obvious at each call site.
Object? pendingError(WidgetTester t) => t.takeException();
