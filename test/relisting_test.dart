import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/core/utils/relisting_check.dart';
import 'package:bonnetcheck/data/models/car_model.dart';
import 'package:bonnetcheck/data/models/plate_snapshot_model.dart';

/// What this plate's earlier listings say about the one being read.
///
/// The raw material has travelled with every listing since the odometer
/// rollback check was built — `plateHistorySnapshot`, a record per previous
/// listing of the same plate. Nothing was asking it the two questions here:
/// is one of those listings **still up**, and did the **kind of seller** change
/// recently.
void main() {
  PlateSnapshot snap({
    required String carId,
    int km = 90000,
    double price = 80000,
    SellerType seller = SellerType.private,
    String area = 'תל אביב',
    required DateTime at,
  }) =>
      PlateSnapshot(
        id: carId,
        carId: carId,
        km: km,
        price: price,
        sellerType: seller,
        area: area,
        createdAt: at,
      );

  final now = DateTime(2026, 8, 27);

  group('which earlier listings there are', () {
    test('the listing being read is never one of its own findings', () {
      final out = RelistingCheck.previous(
        currentCarId: 'me',
        history: [snap(carId: 'me', at: now)],
        activeCarIds: {'me'},
      );
      expect(out, isEmpty,
          reason: 'a listing is not a duplicate of itself');
    });

    test('newest first', () {
      final out = RelistingCheck.previous(
        currentCarId: 'me',
        history: [
          snap(carId: 'old', at: DateTime(2025, 1, 1)),
          snap(carId: 'recent', at: DateTime(2026, 6, 1)),
        ],
        activeCarIds: const {},
      );
      expect(out.first.snapshot.carId, 'recent');
    });
  });

  group('another live listing for the same plate', () {
    test('found when the earlier listing is still active', () {
      final earlier = RelistingCheck.previous(
        currentCarId: 'me',
        history: [snap(carId: 'other', at: DateTime(2026, 8, 1))],
        activeCarIds: {'other'},
      );
      expect(RelistingCheck.concurrent(earlier), hasLength(1));
    });

    test('a closed earlier listing is not a duplicate', () {
      // The ordinary case, and by far the most common: the car was on the
      // market before and that listing ended. Reporting it as a live duplicate
      // would make the finding worthless within a week.
      final earlier = RelistingCheck.previous(
        currentCarId: 'me',
        history: [snap(carId: 'other', at: DateTime(2026, 8, 1))],
        activeCarIds: const {},
      );
      expect(RelistingCheck.concurrent(earlier), isEmpty);
    });
  });

  group('a recent relist by a different kind of seller', () {
    List<Relisting> history(SellerType seller, DateTime at) =>
        RelistingCheck.previous(
          currentCarId: 'me',
          history: [snap(carId: 'past', seller: seller, at: at)],
          activeCarIds: const {},
        );

    test('private then dealer, weeks apart, is reported', () {
      final flip = RelistingCheck.recentSellerChange(
        previous: history(SellerType.private, DateTime(2026, 7, 20)),
        currentSellerType: SellerType.dealer,
        now: now,
      );
      expect(flip, isNotNull);
      expect(flip!.snapshot.sellerType, SellerType.private);
    });

    test('the same kind of seller twice is not a finding', () {
      // Somebody relisting their own car after it did not sell. Nothing
      // happened that a buyer needs told.
      expect(
        RelistingCheck.recentSellerChange(
          previous: history(SellerType.private, DateTime(2026, 7, 20)),
          currentSellerType: SellerType.private,
          now: now,
        ),
        isNull,
      );
    });

    test('outside the window it stops being informative', () {
      // A car that changed hands two years ago is just a car with a history.
      expect(
        RelistingCheck.recentSellerChange(
          previous: history(SellerType.private, DateTime(2024, 1, 1)),
          currentSellerType: SellerType.dealer,
          now: now,
        ),
        isNull,
      );
      expect(RelistingCheck.flipWindow, const Duration(days: 90));
    });
  });

  group('a seller relisting their own car is not a finding', () {
    // The false-positive side, which is where a duplicate detector does its
    // damage. A car being on the market more than once over its life is the
    // ordinary case, not a signal — most cars are sold more than once — and a
    // finding that fires on it teaches buyers to ignore the panel entirely,
    // which costs them the odometer rollback next to it.

    test('three earlier listings, all ended, are worth nothing to report', () {
      // The same owner listing the same plate in 2024, 2025 and again now.
      // Nothing here is evidence of anything, and the app must say nothing
      // rather than count history at the reader.
      final earlier = RelistingCheck.previous(
        currentCarId: 'now',
        history: [
          snap(carId: 'first', at: DateTime(2024, 3, 1), price: 96000),
          snap(carId: 'second', at: DateTime(2025, 4, 1), price: 88000),
          snap(carId: 'third', at: DateTime(2026, 5, 1), price: 82000),
        ],
        activeCarIds: const {},
      );

      expect(RelistingCheck.concurrent(earlier), isEmpty);
      expect(
        RelistingCheck.recentSellerChange(
          previous: earlier,
          currentSellerType: SellerType.private,
          now: now,
        ),
        isNull,
      );
    });

    test('the finding counts live listings, not history', () {
      // One forgotten listing among three past ones is one finding. The count
      // goes into the buyer's sentence — "also advertised in 3 other ads"
      // where there is one is an accusation the records do not support.
      final earlier = RelistingCheck.previous(
        currentCarId: 'now',
        history: [
          snap(carId: 'first', at: DateTime(2024, 3, 1)),
          snap(carId: 'second', at: DateTime(2025, 4, 1)),
          snap(carId: 'stale', at: DateTime(2026, 5, 1)),
        ],
        activeCarIds: {'stale'},
      );

      final live = RelistingCheck.concurrent(earlier);
      expect(live, hasLength(1));
      expect(live.single.snapshot.carId, 'stale');
    });

    test('a listing is identified by its id, so an edit cannot duplicate it',
        () {
      // Everything in a plate's history is the same plate by construction —
      // the collection is keyed by it. What separates "the car has been listed
      // twice" from "this listing was written down twice" is the listing id,
      // and it is the only thing that can: the snapshot carries no seller.
      final earlier = RelistingCheck.previous(
        currentCarId: 'now',
        history: [
          snap(carId: 'now', at: DateTime(2026, 8, 1), price: 84000),
          snap(carId: 'now', at: DateTime(2026, 8, 20), price: 82000),
        ],
        activeCarIds: {'now'},
      );

      expect(earlier, isEmpty,
          reason: 'a seller who corrected their own price is not two sellers');
    });

    test('only publishing a listing writes to a plate history', () {
      // The rule behind the test above, where it is enforced. A snapshot
      // written when a seller edits a price would put a second entry in their
      // own car's history, and the next reader of that history would be shown
      // their correction as a second listing of the car.
      final callers = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) =>
              f.readAsStringSync().contains('recordPlateSnapshot(') &&
              !f.path.contains('car_repository.dart'))
          .toList();

      expect(callers, isNotEmpty, reason: 'somebody has to record them');
      for (final f in callers) {
        final src = f.readAsStringSync();
        expect(
          src.contains('createListing(') || src.contains('publishFromVehicle('),
          isTrue,
          reason: '${f.path} records a plate snapshot without publishing',
        );
      }
    });

    test('a plate snapshot names no person and no plate', () {
      // It is copied verbatim onto `cars/{id}`, which is world-readable. The
      // obvious way to make this feature cleverer is to put the seller id in
      // the snapshot — then "same seller relisting" could be told from "two
      // strangers with one car", which is exactly the distinction the checks
      // above have to work around. It would also hand every buyer a map of
      // which listings belong to the same person, keyed by a car's history,
      // and that is not ours to publish. The awkwardness is the price.
      final stored = PlateSnapshot(
        id: 's1',
        carId: 'c1',
        km: 90000,
        price: 82000,
        sellerType: SellerType.private,
        area: 'תל אביב',
        createdAt: now,
      ).toMap();

      for (final leak in const ['sellerId', 'uid', 'ownerId', 'plate', 'name']) {
        expect(stored.containsKey(leak), isFalse, reason: leak);
      }
    });
  });

  test('prices are written the way the rest of the app writes them', () {
    expect(RelistingCheck.shekels(98000), '98,000');
    expect(RelistingCheck.shekels(7500.4), '7,500');
    expect(RelistingCheck.shekels(950), '950');
  });

  test('VIN matching is documented as impossible, not forgotten', () {
    // A car re-plated to escape its own history is the strongest fraud signal
    // there is, and it cannot be looked for from a client: the public listing
    // document carries neither the plate nor the VIN, deliberately, so a buyer
    // is never handed the identifier that would let them query a stranger's
    // car. Finding it would mean publishing the very thing the privacy design
    // withholds.
    //
    // Pinned so the limitation cannot be quietly dropped from the source and
    // rediscovered later as a "missing feature".
    final source =
        File('lib/core/utils/relisting_check.dart').readAsStringSync();
    expect(source, contains('VIN'));
    expect(source, contains('neither the plate nor the VIN'));
  });
}
