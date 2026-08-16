import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/data/models/car_model.dart';
import 'package:bonnetcheck/data/models/vehicle.dart';
import 'package:bonnetcheck/presentation/widgets/car_card_widget.dart';
import 'package:bonnetcheck/presentation/widgets/documented_history_card.dart';

/// The passport is only worth keeping if the work shows up on the listing.
/// These pin the two ends of that: what a listing carries away from a vehicle
/// at publish time, and what a buyer sees because of it.
void main() {
  CarModel car({
    bool documented = false,
    int services = 0,
    int months = 0,
    String? vehicleId,
  }) =>
      CarModel(
        id: 'c1',
        plate: '88888888',
        make: 'מאזדה',
        model: 'CX-5',
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
        vehicleId: vehicleId,
        hasDocumentedHistory: documented,
        serviceCount: services,
        historySpanMonths: months,
      );

  Widget host(Widget child, {double width = 390}) => ProviderScope(
        child: MaterialApp(
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
        ),
      );

  group('what a listing carries from the passport', () {
    test('a listing made the ordinary way claims no history', () {
      // Every listing that existed before the passport did. Their documents
      // have none of these fields, so the defaults are what they get.
      final legacy = CarModel.fromFirestore(const {
        'plate': '88888888',
        'make': 'מאזדה',
      }, 'c1');

      expect(legacy.vehicleId, isNull);
      expect(legacy.hasDocumentedHistory, isFalse);
      expect(legacy.serviceCount, 0);
      expect(legacy.historySpanMonths, 0);
    });

    test('the badge is copied at publish time, not read live', () {
      // Deliberate: a seller who logs another service later must not silently
      // change what an already-published listing claimed.
      final published = car(documented: true, services: 4, months: 14);
      final data = published.toFirestore();

      expect(data['hasDocumentedHistory'], isTrue);
      expect(data['serviceCount'], 4);
      expect(data['historySpanMonths'], 14);
    });

    test('the vehicle decides the badge, and both halves are required', () {
      Vehicle v({required int count, required int spanDays}) => Vehicle(
            id: 'v1',
            plate: '88888888',
            ownerId: 'u1',
            serviceCount: count,
            firstServiceAt: DateTime(2025, 1, 1),
            lastServiceAt: DateTime(2025, 1, 1).add(Duration(days: spanDays)),
            createdAt: DateTime(2025, 1, 1),
          );

      expect(v(count: 3, spanDays: 200).hasDocumentedHistory, isTrue);
      expect(v(count: 2, spanDays: 200).hasDocumentedHistory, isFalse);
      expect(v(count: 5, spanDays: 30).hasDocumentedHistory, isFalse);
    });
  });

  group('the card', () {
    testWidgets('shows the badge only when the listing earned it',
        (tester) async {
      await tester.pumpWidget(host(
        CarCard(car: car(documented: true), onTap: () {}),
      ));
      expect(find.text('תיק מתועד'), findsOneWidget);
    });

    testWidgets('says nothing at all when there is no documented history',
        (tester) async {
      // Silence, not "no records kept" — the seller may have a folder in the
      // glovebox, and the badge rewards documentation rather than punishing
      // its absence.
      await tester.pumpWidget(host(CarCard(car: car(), onTap: () {})));
      expect(find.text('תיק מתועד'), findsNothing);
      expect(find.textContaining('ללא תיעוד'), findsNothing);
    });
  });

  group('the listing page', () {
    testWidgets('renders nothing for a listing with no passport behind it',
        (tester) async {
      await tester.pumpWidget(host(DocumentedHistoryCard(car: car())));

      expect(find.text('היסטוריית טיפולים'), findsNothing);
      // Zero height: it takes the width its parent hands it, but occupies no
      // vertical space, so it leaves no gap on the listing page.
      expect(tester.getSize(find.byType(DocumentedHistoryCard)).height, 0);
    });
  });
}
