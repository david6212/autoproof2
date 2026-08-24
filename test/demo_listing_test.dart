import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/data/models/car_model.dart';
import 'package:bonnetcheck/presentation/widgets/app_card.dart';
import 'package:bonnetcheck/presentation/widgets/car/demo_listing_notice.dart';
import 'package:bonnetcheck/presentation/widgets/car_card_widget.dart';

/// Four demonstration listings are live on the public marketplace, and until
/// now nothing in the app said so.
///
/// They were rebuilt in August after the compliance audit found the previous
/// four attached to real, registered vehicles. The rule they were rebuilt
/// under — a demo plate must return nothing from any registry dataset — is
/// what makes them safe, and it is also what makes them invisible: with no
/// plate in the public document and no registry snapshot, their official
/// sections simply render nothing. A buyer sees a car with a price, a
/// mileage, an area and a "נתונים רשמיים" badge, and no way to know that all
/// of it was typed by us.
///
/// `demo: true` has been on those documents the whole time. These tests are
/// about reading it.
void main() {
  CarModel car({bool demo = false}) => CarModel(
        id: 'c1',
        plate: '',
        make: 'מאזדה',
        model: 'CX-5',
        year: 2019,
        price: 132000,
        km: 92000,
        hand: 2,
        area: 'תל אביב',
        sellerId: 'demo-seller',
        status: CarStatus.active,
        photos: const [],
        reasonForSelling: '',
        createdAt: DateTime(2026, 1, 1),
        isDemo: demo,
      );

  Widget host(Widget child) => ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SizedBox(width: 390, child: child),
            ),
          ),
        ),
      );

  group('the flag survives the trip through Firestore', () {
    test('a document marked demo is read as one', () {
      // The four live documents carry exactly this: a boolean `demo`.
      expect(CarModel.fromFirestore(const {'demo': true}, 'x').isDemo, isTrue);
    });

    test('an ordinary listing is not', () {
      expect(CarModel.fromFirestore(const {}, 'x').isDemo, isFalse);
      expect(CarModel.fromFirestore(const {'demo': false}, 'x').isDemo, isFalse);
    });

    test('a real listing does not carry the key at all', () {
      // Not `demo: false`. A key on every document is an invitation for the
      // next reader to test it for presence instead of for truth.
      expect(car().toFirestore().containsKey('demo'), isFalse);
      expect(car(demo: true).toFirestore()['demo'], isTrue);
    });
  });

  group('the card', () {
    testWidgets('a demo card does not claim official data', (tester) async {
      // This is the finding in miniature: the badge means "the state was
      // asked about this vehicle", and for a demo nobody was asked.
      await tester.pumpWidget(host(
        CarCard(car: car(demo: true), onTap: () {}),
      ));

      expect(find.text('נתונים רשמיים'), findsNothing);
      expect(find.text('מודעת הדגמה'), findsOneWidget);
    });

    testWidgets('a real card is untouched', (tester) async {
      await tester.pumpWidget(host(CarCard(car: car(), onTap: () {})));

      expect(find.text('נתונים רשמיים'), findsOneWidget);
      expect(find.text('מודעת הדגמה'), findsNothing);
    });
  });

  group('the notice', () {
    testWidgets('says the car does not exist, not that data is missing',
        (tester) async {
      await tester.pumpWidget(host(DemoListingNotice(car: car(demo: true))));

      expect(find.text('מודעת הדגמה'), findsOneWidget);
      expect(find.textContaining('הרכב הזה אינו קיים'), findsOneWidget);
      // The empty government section is the thing a reader would otherwise
      // read as a fault in the app. It is explained, not left to be guessed.
      expect(find.textContaining('ולא בגלל תקלה'), findsOneWidget);
    });

    testWidgets('renders nothing on a real listing', (tester) async {
      await tester.pumpWidget(host(DemoListingNotice(car: car())));
      expect(find.text('מודעת הדגמה'), findsNothing);
    });
  });

  testWidgets('the source badge can say "we made this up"', (tester) async {
    // The spec panel on a demo listing shows a fuel type, a colour and an
    // ownership class that came from nowhere. The badge under that panel used
    // to name the Ministry of Transport for all of them.
    await tester.pumpWidget(
        host(const DataSourceBadge(source: DataSource.demo)));

    expect(find.textContaining('נתוני הדגמה'), findsOneWidget);
    expect(find.textContaining('לא ממשרד התחבורה'), findsOneWidget);
  });
}
