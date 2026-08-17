import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/data/models/car_model.dart';
import 'package:bonnetcheck/data/models/vehicle.dart';

/// A seller who publishes the ordinary way can now document what they have
/// done to the car, and it goes into the same append-only history the passport
/// uses — not a free-text box.
///
/// The alternative was tempting and worthless: a "what I did to the car" field
/// is what the description field already is. Undated, editable, unbounded, and
/// therefore worth nothing to the person reading it. What makes the timeline
/// mean something is that each entry carries a date and an odometer reading
/// that cannot go backwards, and that none of it can be changed afterwards.
void main() {
  CarModel car({
    int services = 0,
    int months = 0,
    bool documented = false,
    String? vehicleId,
  }) =>
      CarModel(
        id: 'c1',
        plate: '20837803',
        make: 'סקודה',
        model: 'אוקטביה',
        year: 2018,
        price: 89000,
        km: 120000,
        hand: 2,
        area: 'תל אביב',
        sellerId: 'seller',
        status: CarStatus.active,
        photos: const [],
        reasonForSelling: '',
        createdAt: DateTime(2026, 8, 1),
        vehicleId: vehicleId,
        hasDocumentedHistory: documented,
        serviceCount: services,
        historySpanMonths: months,
      );

  group('a listing published the ordinary way', () {
    test('starts with no history and claims none', () {
      final c = car();
      expect(c.vehicleId, isNull);
      expect(c.serviceCount, 0);
      expect(c.hasDocumentedHistory, isFalse);
    });

    test('carries the history once a passport is attached', () {
      final c = car(vehicleId: 'v1', services: 4, months: 14, documented: true);
      expect(c.vehicleId, 'v1');
      expect(c.hasDocumentedHistory, isTrue);
      expect(c.toFirestore()['serviceCount'], 4);
    });
  });

  group('the badge rule is the same however the car got listed', () {
    Vehicle v({required int count, required int spanDays}) => Vehicle(
          id: 'v1',
          plate: '20837803',
          ownerId: 'seller',
          serviceCount: count,
          firstServiceAt: DateTime(2025, 1, 1),
          lastServiceAt: DateTime(2025, 1, 1).add(Duration(days: spanDays)),
          createdAt: DateTime(2025, 1, 1),
        );

    test('three records over six months earns it', () {
      expect(v(count: 3, spanDays: 200).hasDocumentedHistory, isTrue);
    });

    test('a seller typing five records tonight does not', () {
      // The span comes from the DATES on the records, not from when they were
      // entered. Somebody documenting real past work with real dates earns the
      // badge; somebody adding five entries for this evening does not.
      expect(v(count: 5, spanDays: 0).hasDocumentedHistory, isFalse);
    });

    test('the span is measured across the work, not the typing', () {
      final backdated = v(count: 4, spanDays: 400);
      expect(backdated.historySpanMonths, greaterThan(6));
      expect(backdated.hasDocumentedHistory, isTrue);
    });
  });

  test('a live listing and its passport describe one car', () {
    // While `activeCarId` points at a listing, adding a service updates the
    // listing too — the advert and the history are the same car being sold
    // today. Freezing only protects listings the passport has moved on from.
    final listed = Vehicle(
      id: 'v1',
      plate: '20837803',
      ownerId: 'seller',
      isListed: true,
      activeCarId: 'c1',
      serviceCount: 3,
      firstServiceAt: DateTime(2025, 1, 1),
      lastServiceAt: DateTime(2025, 9, 1),
      createdAt: DateTime(2025, 1, 1),
    );
    expect(listed.isListed, isTrue);
    expect(listed.activeCarId, 'c1');
    expect(listed.hasDocumentedHistory, isTrue);
  });
}
