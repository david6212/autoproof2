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
