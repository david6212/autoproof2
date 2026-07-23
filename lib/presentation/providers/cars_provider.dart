import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/car_model.dart';
import '../../data/repositories/car_repository.dart';
import 'auth_provider.dart';

final carRepositoryProvider = Provider<CarRepository>((ref) {
  return CarRepository();
});

/// Currently selected category filter pill on the home screen.
/// null = "הכל" (all).
final carFilterProvider = StateProvider<String?>((ref) => null);

/// Stream of all active listings.
final activeCarsProvider = StreamProvider<List<CarModel>>((ref) {
  return ref.watch(carRepositoryProvider).streamActiveCars();
});

/// Active listings after applying the selected category filter.
/// (Category is a lightweight client-side text match for the MVP.)
final filteredCarsProvider = Provider<AsyncValue<List<CarModel>>>((ref) {
  final cars = ref.watch(activeCarsProvider);
  final filter = ref.watch(carFilterProvider);
  return cars.whenData((list) {
    if (filter == null) return list;
    return list
        .where((c) =>
            c.model.contains(filter) ||
            c.make.contains(filter) ||
            (c.govData?['fuelType']?.toString().contains(filter) ?? false))
        .toList();
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
