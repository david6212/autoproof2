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

/// Toggles saved state for a car. No-op if not signed in.
final toggleSavedProvider =
    Provider<Future<void> Function(String carId, bool save)>((ref) {
  return (carId, save) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    await ref.read(carRepositoryProvider).toggleSaved(user.uid, carId, save);
  };
});
