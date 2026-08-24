import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/data/models/car_model.dart';

/// The plate must not be in the document the world can read.
///
/// `cars/{id}` is `allow read: if true`. While the plate sat in it, masking
/// the number on screen protected nobody: one anonymous `curl` returned every
/// plate on the platform joined to price, mileage and area. It lives in
/// `cars/{id}/private/registry` now, which only the listing's seller can read,
/// and buyers are shown the registry's ANSWER instead — carried on the listing
/// with neither plate nor VIN inside.
void main() {
  CarModel car() => CarModel(
        id: 'abc',
        plate: '11111111',
        make: 'מאזדה',
        model: 'CX-5',
        year: 2017,
        price: 98000,
        km: 92000,
        hand: 2,
        area: 'רמת גן',
        sellerId: 'seller-1',
        status: CarStatus.active,
        photos: const [],
        reasonForSelling: '',
        createdAt: DateTime(2026, 8, 24),
      );

  test('the public document carries no plate', () {
    final map = car().toFirestore();

    expect(map.containsKey('plate'), isFalse);
    expect(map.values.join(' ').contains('11111111'), isFalse,
        reason: 'not under another key either');
  });

  test('the model still holds it in memory, for the seller who has it', () {
    // Dropping it from the model would break publishing and the seller's own
    // refresh; the point is only that it is never *written* publicly.
    expect(car().plate, '11111111');
  });

  test('both write paths store it privately', () {
    final repo =
        File('lib/data/repositories/car_repository.dart').readAsStringSync();
    expect(repo, contains("collection('private').doc('registry')"));
    // createListing and publishFromVehicle both have to do it, or a listing
    // published from a passport would lose its plate entirely.
    expect('_writePrivatePlate('.allMatches(repo).length, greaterThanOrEqualTo(3),
        reason: 'declared once and called from both creation paths');
  });

  test('the rules gate the private document and the plate history', () {
    final rules = File('firestore.rules').readAsStringSync();
    expect(rules, contains('match /private/{docId}'));
    expect(rules, contains('carSellerId(carId) == request.auth.uid'));
    // plate_history was `allow read: if true` — anyone could walk a car park
    // and build a mileage history for every plate they photographed.
    expect(rules.contains('''match /plate_history/{plate}/snapshots/{snapshotId} {
      allow read: if true;'''), isFalse);
  });
}
