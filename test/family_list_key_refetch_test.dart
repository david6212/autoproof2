import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/data/models/car_model.dart';
import 'package:bonnetcheck/data/models/place.dart';
import 'package:bonnetcheck/data/models/plate_snapshot_model.dart';
import 'package:bonnetcheck/data/models/service_record.dart';
import 'package:bonnetcheck/data/repositories/car_repository.dart';
import 'package:bonnetcheck/data/repositories/place_repository.dart';
import 'package:bonnetcheck/presentation/providers/cars_provider.dart';
import 'package:bonnetcheck/presentation/providers/place_provider.dart';
import 'package:bonnetcheck/presentation/widgets/car/car_active_warnings.dart';
import 'package:bonnetcheck/presentation/widgets/garage/my_garages_section.dart';

/// Two widgets that key a Riverpod family on a freshly built `List<String>`.
///
/// ## The diagnosis
///
/// A family caches its providers by `==` on the argument. Dart lists have
/// identity equality, so a list rebuilt inside `build()` never equals the one
/// the previous build passed: every build is a cache miss, which starts a
/// fetch, which completes, which notifies, which rebuilds — an unbounded loop
/// of Firestore reads that runs for as long as the screen is open, and that
/// nobody notices, because every individual answer is correct and arrives
/// quickly.
///
/// `CarActiveWarnings` does it at `car_active_warnings.dart:88`
/// (`concurrentListingsProvider([for (final s in history) s.carId])`) and
/// `MyGaragesSection` at `my_garages_section.dart:33-44`
/// (`placesByIdsProvider(_usedPlaceIds)`). On the Spark plan this is the exact
/// shape that empties a day's quota in an afternoon — and the car page is the
/// page everybody opens.
///
/// ## Why the rest of the suite cannot see it
///
/// `active_warnings_section_test.dart` mounts `ActiveWarningsSection`, the
/// presentational half, which is handed a finished list and watches nothing.
/// `CarActiveWarnings` — the `ConsumerWidget` that does the watching — was
/// mounted by no test at all. A defect that lives entirely in the wiring can
/// only be caught by mounting the thing that does the wiring, with a
/// repository that counts.
void main() {
  // The fakes are at the bottom of the file. `implements` rather than
  // `extends`: the real constructors reach `FirebaseFirestore.instance`, and
  // the test would die on the way in.

  Widget host(List<Override> overrides, Widget child) => ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.light,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SingleChildScrollView(child: child),
            ),
          ),
        ),
      );

  group('a car page does not re-read its plate history on every frame', () {
    CarModel car(String id) => CarModel(
          id: id,
          plate: '12345678',
          make: 'מאזדה',
          model: 'CX-5',
          year: 2019,
          price: 132000,
          km: 92000,
          hand: 2,
          area: 'חיפה',
          sellerId: 's',
          status: CarStatus.active,
          photos: const [],
          reasonForSelling: '',
          createdAt: DateTime(2026, 1, 1),
          // Non-empty, so `listingGov` answers from the listing itself and no
          // widget test goes near data.gov.il.
          govSnapshot: const {'make': 'מאזדה', 'model': 'CX-5', 'year': 2019},
          plateHistorySnapshot: [
            PlateSnapshot(
              id: 's1',
              carId: 'older-listing',
              km: 90000,
              price: 139000,
              sellerType: SellerType.private,
              area: 'חיפה',
              createdAt: DateTime(2026, 5, 1),
            ).toMap(),
          ],
        );

    late _CountingCarRepository repo;

    Widget subject() => host(
          [carRepositoryProvider.overrideWithValue(repo)],
          CarActiveWarnings(car: car('this-listing')),
        );

    setUp(() {
      repo = _CountingCarRepository({'older-listing': car('older-listing')});
    });

    testWidgets('one earlier listing costs one read, however often it builds',
        (t) async {
      // How many documents a screen reads must be a function of the data on
      // it, never of how many frames it happened to draw. This is the
      // assertion that fails the moment a family is keyed on something that
      // does not compare equal.
      await t.pumpWidget(subject());
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 16));
      }

      expect(repo.reads, lessThanOrEqualTo(1),
          reason: 'one earlier listing, eight frames, ${repo.reads} reads');
    });

    testWidgets('the page goes quiet once it has loaded', (t) async {
      // The symptom as a person would meet it: a card that never stops
      // rebuilding. `pumpAndSettle` is the only tool in the suite that can see
      // it, and three seconds of fake time is an eternity for one document.
      await t.pumpWidget(subject());

      await t.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 3),
      );

      // Having settled, it did ask — otherwise this would pass just as well on
      // a card that never looked.
      expect(repo.reads, 1);
    });

    testWidgets('the finding it exists to draw still arrives', (t) async {
      // The two above must not be satisfiable by a card that stopped looking.
      // A second live listing for the same plate is the finding the watch is
      // there for, and it has to reach the screen.
      await t.pumpWidget(subject());
      await t.pump();
      await t.pump();

      // The other listing's price, carried all the way from the fake: what a
      // buyer gains here is the number on the duplicate, not an adjective.
      expect(find.textContaining('139,000'), findsWidgets);
    });
  });

  group('the garages section does not re-read its places on every frame', () {
    ServiceRecord service(String id, String placeId) => ServiceRecord(
          id: id,
          type: ServiceType.routine,
          title: 'טיפול',
          date: DateTime(2026, 6, 1),
          km: 90000,
          cost: 900,
          placeId: placeId,
          addedByOwnerId: 'me',
          createdAt: DateTime(2026, 6, 1),
        );

    testWidgets('two garages cost one lookup, however often it builds',
        (t) async {
      // The same defect, the same cost, one screen further in. Worth pinning
      // separately: the two were written months apart, which is how a
      // list-shaped family key becomes a house style before anyone notices.
      final repo = _CountingPlaceRepository();

      await t.pumpWidget(host(
        [
          placeRepositoryProvider.overrideWithValue(repo),
          // The card also reads whether *you* reviewed the place, which needs
          // an account. Not what is under test.
          myPlaceReviewProvider.overrideWith((ref, id) => null),
        ],
        MyGaragesSection(
          vehicleId: 'v1',
          services: [service('a', 'p1'), service('b', 'p2')],
        ),
      ));
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 16));
      }

      expect(repo.lookups, lessThanOrEqualTo(1),
          reason: 'two garages, eight frames, ${repo.lookups} lookups');
    });
  });
}

class _CountingCarRepository implements CarRepository {
  _CountingCarRepository(this._cars);

  final Map<String, CarModel> _cars;

  /// Every `getCarById` this screen caused — the whole point of the file.
  int reads = 0;

  @override
  Future<CarModel?> getCarById(String id) async {
    reads++;
    return _cars[id];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CountingPlaceRepository implements PlaceRepository {
  int lookups = 0;

  @override
  Future<List<Place>> byIds(Iterable<String> ids) async {
    lookups++;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
