import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/support_contact.dart';
import '../../data/models/car_model.dart';
import '../../data/models/car_note_model.dart';
import '../../data/models/plate_snapshot_model.dart';
import '../../data/repositories/car_repository.dart';
import '../../data/repositories/price_watch_repository.dart';
import 'auth_provider.dart';

final carRepositoryProvider = Provider<CarRepository>((ref) {
  return CarRepository();
});

/// Free-text search query on the home screen (make / model / area).
final carSearchProvider = StateProvider<String>((ref) => '');

/// Rich buyer filters (body types + price/year/km/area) from the filter sheet.
class CarFilters {
  static const double priceCap = 500000;
  static const int yearFloor = 2005;
  static const int kmCap = 400000;

  /// The other end of each range. A filter has two bounds because a buyer
  /// thinks in both — "between 2018 and 2022", not "anything after 2018".
  /// These are the values that mean "no bound set on this side".
  static const double priceFloor = 0;
  static const int kmFloor = 0;

  /// Deliberately far out. It only has to be past any model year the registry
  /// can return, so that leaving it alone filters nothing.
  static const int yearCap = 2035;

  final Set<String> types; // body-type categories (up to 4)
  final double minPrice;
  final double maxPrice;
  final int minYear;
  final int maxYear;
  final int minKm;
  final int maxKm;
  final String? area;
  final String? make; // manufacturer
  final String? model; // model name
  final int? maxHand; // max previous owners
  final String? fuel; // drivetrain category (בנזין / דיזל / היברידי / חשמלי)
  final String? ownership; // 'פרטית' / 'ליסינג/חברה'
  final String? colorCat; // colour bucket (לבן / שחור / אפור / כחול / אדום)

  // Backed by the models dataset (see ModelSpec) — these were decorative until
  // that source was wired in.
  final String? engineRange; // '1200-1600' / '1600-2000' / '2000+'
  final int? minSeats; // 5 / 7 / 8
  final String? drivetrain; // '4X4' / '4X2'

  const CarFilters({
    this.types = const {},
    this.minPrice = priceFloor,
    this.maxPrice = priceCap,
    this.minYear = yearFloor,
    this.maxYear = yearCap,
    this.minKm = kmFloor,
    this.maxKm = kmCap,
    this.area,
    this.make,
    this.model,
    this.maxHand,
    this.fuel,
    this.ownership,
    this.colorCat,
    this.engineRange,
    this.minSeats,
    this.drivetrain,
  });

  CarFilters copyWith({
    Set<String>? types,
    double? minPrice,
    double? maxPrice,
    int? minYear,
    int? maxYear,
    int? minKm,
    int? maxKm,
    String? area,
    bool clearArea = false,
    String? make,
    bool clearMake = false,
    String? model,
    bool clearModel = false,
    int? maxHand,
    bool clearHand = false,
    String? fuel,
    bool clearFuel = false,
    String? ownership,
    bool clearOwnership = false,
    String? colorCat,
    bool clearColor = false,
    String? engineRange,
    bool clearEngine = false,
    int? minSeats,
    bool clearSeats = false,
    String? drivetrain,
    bool clearDrivetrain = false,
  }) {
    return CarFilters(
      types: types ?? this.types,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      minYear: minYear ?? this.minYear,
      maxYear: maxYear ?? this.maxYear,
      minKm: minKm ?? this.minKm,
      maxKm: maxKm ?? this.maxKm,
      area: clearArea ? null : (area ?? this.area),
      make: clearMake ? null : (make ?? this.make),
      model: clearModel ? null : (model ?? this.model),
      maxHand: clearHand ? null : (maxHand ?? this.maxHand),
      fuel: clearFuel ? null : (fuel ?? this.fuel),
      ownership: clearOwnership ? null : (ownership ?? this.ownership),
      colorCat: clearColor ? null : (colorCat ?? this.colorCat),
      engineRange: clearEngine ? null : (engineRange ?? this.engineRange),
      minSeats: clearSeats ? null : (minSeats ?? this.minSeats),
      drivetrain: clearDrivetrain ? null : (drivetrain ?? this.drivetrain),
    );
  }

  bool get isDefault =>
      types.isEmpty &&
      minPrice <= priceFloor &&
      maxPrice >= priceCap &&
      minYear <= yearFloor &&
      maxYear >= yearCap &&
      minKm <= kmFloor &&
      maxKm >= kmCap &&
      area == null &&
      make == null &&
      model == null &&
      maxHand == null &&
      fuel == null &&
      ownership == null &&
      colorCat == null &&
      engineRange == null &&
      minSeats == null &&
      drivetrain == null;

  /// Number of active (non-default) filter groups, for the badge.
  int get activeCount =>
      (types.isNotEmpty ? 1 : 0) +
      // A range counts once however many of its two ends are set — "price"
      // is one thing the buyer narrowed, not two.
      ((minPrice > priceFloor || maxPrice < priceCap) ? 1 : 0) +
      ((minYear > yearFloor || maxYear < yearCap) ? 1 : 0) +
      ((minKm > kmFloor || maxKm < kmCap) ? 1 : 0) +
      (area != null ? 1 : 0) +
      (make != null ? 1 : 0) +
      (model != null ? 1 : 0) +
      (maxHand != null ? 1 : 0) +
      (fuel != null ? 1 : 0) +
      (ownership != null ? 1 : 0) +
      (colorCat != null ? 1 : 0) +
      (engineRange != null ? 1 : 0) +
      (minSeats != null ? 1 : 0) +
      (drivetrain != null ? 1 : 0);
}

final carFiltersProvider =
    StateProvider<CarFilters>((ref) => const CarFilters());

/// Body-type category for the filter pills.
///
/// Prefers the official `merkav` value from the models dataset when the listing
/// carries one; the keyword guessing below is the fallback for listings created
/// before that source existed, or for models it doesn't cover.
String carBodyType(CarModel c) {
  final official = c.spec?.bodyType ?? '';
  if (official.isNotEmpty) {
    if (official.contains('שטח') || official.contains('פנאי')) {
      return 'קרוסאובר';
    }
    // Powertrain categories outrank shape: an electric sedan belongs under
    // "חשמלי" for a buyer browsing these pills.
    final fuel = c.fuelCategory;
    if (fuel == 'חשמלי') return 'חשמלי';
    if (fuel == 'היברידי') return 'היברידי';
    if (official.contains('קופה') || official.contains('ספורט')) {
      return 'ספורט';
    }
    return 'משפחתי';
  }

  final s = '${c.make} ${c.model}'.toLowerCase();
  bool has(List<String> ks) => ks.any((k) => s.contains(k));
  if (has(['cx', 'טוסון', 'tucson', 'קרוסאובר', 'rav', 'x1', 'x3', 'x5',
      'q3', 'q5', 'glc', 'tiguan', 'קאשקאי', 'qashqai', 'sportage', 'סורנטו'])) {
    return 'קרוסאובר';
  }
  if (has(['חשמל', 'electric', ' ev', 'tesla', 'טסלה', 'ioniq', 'atto', 'אטו'])) {
    return 'חשמלי';
  }
  if (has(['hybrid', 'היבר', 'phev', 'prius', 'פריוס'])) return 'היברידי';
  if (has(['320', '330', 'm3', 'm4', 'coupe', 'קופה', ' gt', 'amg', 'ספורט',
      'gti', 'golf r', 'rs'])) {
    return 'ספורט';
  }
  return 'משפחתי';
}

/// Whether a listing's engine capacity falls in a filter bucket. Electric cars
/// have no capacity at all, so they never match a capacity filter.
bool _engineInRange(CarModel c, String range) {
  final cc = c.spec?.engineCc;
  if (cc == null) return false;
  return switch (range) {
    '1200-1600' => cc >= 1200 && cc <= 1600,
    '1600-2000' => cc > 1600 && cc <= 2000,
    '2000+' => cc > 2000,
    _ => true,
  };
}

/// Stream of all active listings.
final activeCarsProvider = StreamProvider<List<CarModel>>((ref) {
  return ref.watch(carRepositoryProvider).streamActiveCars();
});

/// Active listings after applying the filter sheet AND the text search.
final filteredCarsProvider = Provider<AsyncValue<List<CarModel>>>((ref) {
  final cars = ref.watch(activeCarsProvider);
  final f = ref.watch(carFiltersProvider);
  final query = ref.watch(carSearchProvider).trim().toLowerCase();
  return cars.whenData((list) {
    return list.where((c) {
      if (f.types.isNotEmpty && !f.types.contains(carBodyType(c))) return false;
      if (c.price < f.minPrice || c.price > f.maxPrice) return false;
      if (c.year < f.minYear || c.year > f.maxYear) return false;
      if (c.km < f.minKm || c.km > f.maxKm) return false;
      if (f.area != null && c.area != f.area) return false;
      if (f.make != null && c.make != f.make) return false;
      if (f.model != null && c.model != f.model) return false;
      if (f.maxHand != null && c.hand > f.maxHand!) return false;
      if (f.fuel != null && c.fuelCategory != f.fuel) return false;
      if (f.colorCat != null && c.colorCategory != f.colorCat) return false;
      if (f.ownership == 'פרטית' && !c.isPrivateOwnership) return false;
      if (f.ownership == 'ליסינג/חברה' && c.isPrivateOwnership) return false;

      // Spec-backed filters. A listing without a spec is EXCLUDED when one of
      // these is active — saying "1600-2000cc" and getting cars of unknown
      // capacity would make the filter meaningless.
      if (f.engineRange != null && !_engineInRange(c, f.engineRange!)) {
        return false;
      }
      if (f.minSeats != null) {
        final seats = c.spec?.seats;
        if (seats == null || seats < f.minSeats!) return false;
      }
      if (f.drivetrain != null) {
        final dt = c.spec?.drivetrain ?? '';
        if (!dt.toUpperCase().contains(f.drivetrain!.toUpperCase())) {
          return false;
        }
      }

      if (query.isNotEmpty) {
        // The plate is not searchable. Leaving it in would have made the
        // masking cosmetic: type a number, and the one listing it belongs
        // to falls out of a public search.
        final haystack =
            '${c.make} ${c.model} ${c.area}'.toLowerCase();
        if (!haystack.contains(query)) return false;
      }
      return true;
    }).toList();
  });
});

final carByIdProvider =
    FutureProvider.family<CarModel?, String>((ref, id) async {
  return ref.watch(carRepositoryProvider).getCarById(id);
});

/// Which of this plate's earlier listings are still on the market.
///
/// Keyed by the listing ids that `plateHistorySnapshot` already carries, so no
/// plate is needed to ask — which matters, because a buyer has not got one.
///
/// One read per earlier listing, and there are rarely more than two or three.
/// Capped anyway: on the Spark plan an unbounded fan-out on a screen everybody
/// opens is how a daily quota disappears in an afternoon.
final concurrentListingsProvider =
    FutureProvider.autoDispose.family<Set<String>, List<String>>(
        (ref, carIds) async {
  if (carIds.isEmpty) return const <String>{};
  final repo = ref.watch(carRepositoryProvider);
  final ids = carIds.take(5).toList();
  final found = await Future.wait(ids.map(repo.getCarById));
  return {
    for (final car in found)
      if (car != null && car.status == CarStatus.active) car.id,
  };
});

/// The current user's active listing (null if none or not signed in).
final myActiveListingProvider = Provider<AsyncValue<CarModel?>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  final cars = ref.watch(activeCarsProvider);
  if (user == null) return const AsyncData(null);
  return cars.whenData((list) {
    for (final c in list) {
      if (c.sellerId == user.uid) return c;
    }
    return null;
  });
});

/// Set of saved car ids for the current user (empty if not signed in).
final savedIdsProvider = StreamProvider<Set<String>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(<String>{});
  return ref.watch(carRepositoryProvider).streamSavedIds(user.uid);
});

/// The current user's saved cars.
final savedCarsProvider = StreamProvider<List<CarModel>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(<CarModel>[]);
  return ref.watch(carRepositoryProvider).streamSavedCars(user.uid);
});

/// Updates a listing's status (e.g. mark as sold or remove it). Used by the
/// seller from the "My listing" screen.
final updateListingStatusProvider =
    Provider<Future<void> Function(String carId, CarStatus status)>((ref) {
  return (carId, status) {
    return ref.read(carRepositoryProvider).updateStatus(carId, status);
  };
});

final priceWatchRepositoryProvider =
    Provider<PriceWatchRepository>((ref) => PriceWatchRepository());

/// Toggles saved state for a car. No-op if not signed in.
///
/// Saving also records what the car costs right now, so the saved list can say
/// later that the price came down. Unsaving forgets it, so re-saving next year
/// compares against next year's price rather than this one.
final toggleSavedProvider =
    Provider<Future<void> Function(String carId, bool save, {double? price})>(
        (ref) {
  return (carId, save, {price}) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    await ref.read(carRepositoryProvider).toggleSaved(user.uid, carId, save);

    // Best-effort: the local price note must never cost someone the save.
    try {
      final watch = ref.read(priceWatchRepositoryProvider);
      if (save && price != null) {
        await watch.remember(carId, price);
      } else if (!save) {
        await watch.forget(carId);
      }
    } catch (_) {}
  };
});

/// How much each saved listing has come down since it was saved.
///
/// Empty for anything that has not dropped. Rises are not reported: a seller
/// raising their price is not something a buyer can act on.
final priceDropsProvider = FutureProvider<Map<String, double>>((ref) async {
  final saved = ref.watch(savedCarsProvider).valueOrNull ?? const <CarModel>[];
  if (saved.isEmpty) return const {};
  return ref
      .read(priceWatchRepositoryProvider)
      .dropsFor({for (final c in saved) c.id: c.price});
});

// ---- Plate history (cross-listing memory) ----

/// Past listing snapshots for a plate (newest first), for buyer cross-checks.
final plateHistoryProvider =
    FutureProvider.family<List<PlateSnapshot>, String>((ref, plate) {
  return ref.watch(carRepositoryProvider).getPlateHistory(plate);
});

// ---- Buyer journey progress ----

/// The buyer's current journey stage for a car (defaults to 1). Guests see the
/// default view read-only.
final journeyStageProvider =
    StreamProvider.family<int, String>((ref, carId) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(1);
  return ref.watch(carRepositoryProvider).streamJourneyStage(carId, user.uid);
});

/// Advances (or sets) the buyer's stage for a car. No-op if not signed in.
final setJourneyStageProvider =
    Provider<Future<void> Function(String carId, int stage)>((ref) {
  return (carId, stage) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    await ref.read(carRepositoryProvider).setJourneyStage(carId, user.uid, stage);
  };
});

// ---- Visitor notes ----

/// Public stream of visitor notes for a car (visible to everyone).
final carNotesProvider =
    StreamProvider.family<List<CarNote>, String>((ref, carId) {
  return ref.watch(carRepositoryProvider).streamNotes(carId);
});

/// Adds a note as the current user. No-op if not signed in.
final addNoteProvider =
    Provider<Future<void> Function(String carId, List<NoteTag> tags)>((ref) {
  return (carId, tags) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final profile = ref.read(currentUserModelProvider).valueOrNull;
    final name = (profile?.name.trim().isNotEmpty ?? false)
        ? profile!.name
        : (user.displayName?.trim().isNotEmpty ?? false)
            ? user.displayName!
            : 'מבקר';
    await ref.read(carRepositoryProvider).addNote(
          carId: carId,
          authorUid: user.uid,
          authorName: name,
          tags: tags,
        );
  };
});

/// Deletes a note (author only — enforced by security rules).
final deleteNoteProvider =
    Provider<Future<void> Function(String carId, String noteId)>((ref) {
  return (carId, noteId) =>
      ref.read(carRepositoryProvider).deleteNote(carId, noteId);
});

/// Reports a note for review. No-op if not signed in.
final reportNoteProvider =
    Provider<Future<void> Function(String carId, String noteId)>((ref) {
  return (carId, noteId) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    await ref.read(carRepositoryProvider).reportNote(
          carId: carId,
          noteId: noteId,
          reporterUid: user.uid,
        );
  };
});

/// Submits any correction or data-deletion request. No-op if not signed in.
final submitCorrectionProvider =
    Provider<Future<void> Function({required String kind, String carId, String note})>(
        (ref) {
  return ({required kind, carId = '', note = ''}) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    await ref.read(carRepositoryProvider).submitCorrection(
          kind: kind,
          carId: carId,
          note: note,
          reporterUid: user.uid,
        );

    // And then out to a human.
    //
    // `data_corrections` is `allow read: if false` — no client can read it,
    // by design, because the free-text field would otherwise be a public
    // noticeboard. The consequence nobody had drawn: every request landed
    // somewhere that is only visible by opening the Firebase console, while
    // the published policy promises an answer within 14 days. A promise whose
    // only mechanism is somebody remembering to look is not a mechanism.
    //
    // No server here to send mail with (Spark plan, no Cloud Functions), so
    // the reader's own mail app carries it. The Firestore row stays as the
    // record; this is what makes it arrive.
    await SupportContact.open(
      subject: 'פנייה מהאפליקציה: $kind',
      body: [
        'סוג הפנייה: $kind',
        if (carId.isNotEmpty) 'מודעה: $carId',
        if (note.isNotEmpty) 'פירוט: $note',
      ].join('\n'),
    );
  };
});
