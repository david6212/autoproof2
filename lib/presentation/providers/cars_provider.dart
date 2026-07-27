import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/car_model.dart';
import '../../data/models/car_note_model.dart';
import '../../data/models/plate_snapshot_model.dart';
import '../../data/repositories/car_repository.dart';
import 'auth_provider.dart';

final carRepositoryProvider = Provider<CarRepository>((ref) {
  return CarRepository();
});

/// Free-text search query on the home screen (make / model / area / plate).
final carSearchProvider = StateProvider<String>((ref) => '');

/// Rich buyer filters (body types + price/year/km/area) from the filter sheet.
class CarFilters {
  static const double priceCap = 500000;
  static const int yearFloor = 2005;
  static const int kmCap = 400000;

  final Set<String> types; // body-type categories (up to 4)
  final double maxPrice;
  final int minYear;
  final int maxKm;
  final String? area;
  final String? make; // manufacturer
  final String? model; // model name
  final int? maxHand; // max previous owners
  final String? fuel; // drivetrain category (בנזין / דיזל / היברידי / חשמלי)
  final String? ownership; // 'פרטית' / 'ליסינג/חברה'
  final String? colorCat; // colour bucket (לבן / שחור / אפור / כחול / אדום)

  const CarFilters({
    this.types = const {},
    this.maxPrice = priceCap,
    this.minYear = yearFloor,
    this.maxKm = kmCap,
    this.area,
    this.make,
    this.model,
    this.maxHand,
    this.fuel,
    this.ownership,
    this.colorCat,
  });

  CarFilters copyWith({
    Set<String>? types,
    double? maxPrice,
    int? minYear,
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
  }) {
    return CarFilters(
      types: types ?? this.types,
      maxPrice: maxPrice ?? this.maxPrice,
      minYear: minYear ?? this.minYear,
      maxKm: maxKm ?? this.maxKm,
      area: clearArea ? null : (area ?? this.area),
      make: clearMake ? null : (make ?? this.make),
      model: clearModel ? null : (model ?? this.model),
      maxHand: clearHand ? null : (maxHand ?? this.maxHand),
      fuel: clearFuel ? null : (fuel ?? this.fuel),
      ownership: clearOwnership ? null : (ownership ?? this.ownership),
      colorCat: clearColor ? null : (colorCat ?? this.colorCat),
    );
  }

  bool get isDefault =>
      types.isEmpty &&
      maxPrice >= priceCap &&
      minYear <= yearFloor &&
      maxKm >= kmCap &&
      area == null &&
      make == null &&
      model == null &&
      maxHand == null &&
      fuel == null &&
      ownership == null &&
      colorCat == null;

  /// Number of active (non-default) filter groups, for the badge.
  int get activeCount =>
      (types.isNotEmpty ? 1 : 0) +
      (maxPrice < priceCap ? 1 : 0) +
      (minYear > yearFloor ? 1 : 0) +
      (maxKm < kmCap ? 1 : 0) +
      (area != null ? 1 : 0) +
      (make != null ? 1 : 0) +
      (model != null ? 1 : 0) +
      (maxHand != null ? 1 : 0) +
      (fuel != null ? 1 : 0) +
      (ownership != null ? 1 : 0) +
      (colorCat != null ? 1 : 0);
}

final carFiltersProvider =
    StateProvider<CarFilters>((ref) => const CarFilters());

/// Derives a body-type category from the make/model text so the filter pills
/// work without a dedicated field. Falls back to "משפחתי".
String carBodyType(CarModel c) {
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
      if (c.price > f.maxPrice) return false;
      if (c.year < f.minYear) return false;
      if (c.km > f.maxKm) return false;
      if (f.area != null && c.area != f.area) return false;
      if (f.make != null && c.make != f.make) return false;
      if (f.model != null && c.model != f.model) return false;
      if (f.maxHand != null && c.hand > f.maxHand!) return false;
      if (f.fuel != null && c.fuelCategory != f.fuel) return false;
      if (f.colorCat != null && c.colorCategory != f.colorCat) return false;
      if (f.ownership == 'פרטית' && !c.isPrivateOwnership) return false;
      if (f.ownership == 'ליסינג/חברה' && c.isPrivateOwnership) return false;
      if (query.isNotEmpty) {
        final haystack =
            '${c.make} ${c.model} ${c.area} ${c.plate}'.toLowerCase();
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

/// Writes an anonymous review. CRITICAL: no sellerId field is stored, so the
/// seller can never query or see these reviews.
typedef ReviewWriter = Future<void> Function({
  required String carId,
  required String reviewerId,
  required bool anonymous,
  required List<String> reasons,
  required String text,
});

final reviewWriteProvider = Provider<ReviewWriter>((ref) {
  final repo = ref.read(carRepositoryProvider);
  return ({
    required carId,
    required reviewerId,
    required anonymous,
    required reasons,
    required text,
  }) {
    return repo.addReview(
      carId: carId,
      reviewerId: reviewerId,
      anonymous: anonymous,
      reasons: reasons,
      text: text,
    );
  };
});

/// Updates a listing's status (e.g. mark as sold or remove it). Used by the
/// seller from the "My listing" screen.
final updateListingStatusProvider =
    Provider<Future<void> Function(String carId, CarStatus status)>((ref) {
  return (carId, status) {
    return ref.read(carRepositoryProvider).updateStatus(carId, status);
  };
});

/// Toggles saved state for a car. No-op if not signed in.
final toggleSavedProvider =
    Provider<Future<void> Function(String carId, bool save)>((ref) {
  return (carId, save) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    await ref.read(carRepositoryProvider).toggleSaved(user.uid, carId, save);
  };
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
final addNoteProvider = Provider<
    Future<void> Function(String carId, String text, String sellerFlag)>((ref) {
  return (carId, text, sellerFlag) async {
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
          text: text.trim(),
          sellerFlag: sellerFlag,
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
