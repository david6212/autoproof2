import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/car_compare.dart';
import '../../data/models/car_model.dart';

/// The listings the buyer has ticked for comparison, in the order they picked
/// them — so the columns stay where the buyer put them.
///
/// The listings themselves are held, not their ids. Selection is short-lived
/// (tick, compare, done) and holding the models means the comparison screen
/// never has to re-fetch or handle a listing that vanished mid-flow.
class CompareSelection extends StateNotifier<List<CarModel>> {
  CompareSelection() : super(const []);

  bool contains(String carId) => state.any((c) => c.id == carId);

  bool get isFull => state.length >= maxCompareCars;

  /// Adds or removes a listing. Returns false when the pick was refused
  /// because the limit is reached, so the caller can say so.
  bool toggle(CarModel car) {
    if (contains(car.id)) {
      state = state.where((c) => c.id != car.id).toList();
      return true;
    }
    if (isFull) return false;
    state = [...state, car];
    return true;
  }

  void remove(String carId) {
    state = state.where((c) => c.id != carId).toList();
  }

  void clear() => state = const [];
}

final compareSelectionProvider =
    StateNotifierProvider<CompareSelection, List<CarModel>>(
  (ref) => CompareSelection(),
);

/// Whether the saved list is in "pick cars to compare" mode. Kept out of the
/// selection itself so leaving the mode can preserve what was already ticked.
final compareModeProvider = StateProvider<bool>((ref) => false);
