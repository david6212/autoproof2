import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/data/models/car_model.dart';
import 'package:bonnetcheck/data/repositories/car_repository.dart';

/// "מודעות שאינן פעילות מוסתרות מהשירות לאחר 24 חודשים".
///
/// Hidden from the service, says the published policy — and the cutoff was
/// applied on one read path of three. `streamActiveCars` dropped an expired
/// listing; a direct `/car/:id` link and the saved list both still opened it,
/// with its photos, its description and its seller's uid, for anyone who kept
/// the URL.
///
/// Nothing is 24 months old yet — the oldest listings date from 2026 — so this
/// is a scheduled problem being fixed before it is a live one. The wording
/// says hidden, not deleted, which stays honest: there is no purge job on this
/// plan, and pretending otherwise would be the worse failure.
void main() {
  final tooOld = DateTime.now().subtract(const Duration(days: 800));
  final recent = DateTime.now().subtract(const Duration(days: 30));

  group('the cutoff itself', () {
    test('an 800-day-old listing is outside the window', () {
      expect(CarRepository.withinRetention(tooOld), isFalse);
    });

    test('a 30-day-old listing is inside it', () {
      expect(CarRepository.withinRetention(recent), isTrue);
    });

    test('the boundary day is outside, not inside', () {
      // 24 months is the promise. A listing exactly on the line has reached
      // it, so it is hidden — the same direction `streamActiveCars` already
      // rounded, kept identical so the three paths cannot disagree by a day.
      expect(
        CarRepository.withinRetention(
            DateTime.now().subtract(CarRepository.retention)),
        isFalse,
      );
    });
  });

  group('a shared link to an expired listing', () {
    /// A real listing document, the shape Firestore hands `getCarById`.
    CarModel? open(DateTime createdAt) => CarRepository.visibleCar({
          'make': 'מאזדה',
          'model': '3',
          'sellerId': 'u1',
          'status': 'active',
          'createdAt': Timestamp.fromDate(createdAt),
        }, 'c1');

    test('opens nothing', () async {
      // Null is what the router already renders as the "this page does not
      // exist" screen, so the fix needed no new surface.
      expect(open(tooOld), isNull);
    });

    test('while a live listing still opens', () async {
      // The half that proves the filter is a filter and not a wall.
      expect(open(recent)?.make, 'מאזדה');
    });
  });

  group('and the other two read paths go through the same decision', () {
    final repo =
        File('lib/data/repositories/car_repository.dart').readAsStringSync();

    // The wiring, and only the wiring: the decision itself is tested above
    // against real document data. `getCarById` is one `await` and a call, and
    // `streamSavedCars` fetches each saved id through `getCarById` — so a
    // single cutoff serves the list, the link and the saved screen, with no
    // second copy to drift out of step. Firestore's own classes are sealed,
    // so the `await` is the one link no test here can hold.
    test('the direct link', () {
      expect(repo, contains('return visibleCar(snap.data()!, snap.id);'));
    });

    test('the saved list', () {
      expect(repo, contains('ids.map(getCarById)'));
    });

    test('and the browse list shares the cutoff rather than repeating it', () {
      expect(repo, contains('withinRetention(c.createdAt, cutoff)'));
    });
  });
}
