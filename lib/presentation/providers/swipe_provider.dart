import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/car_model.dart';
import 'cars_provider.dart';

/// Cars swiped away this session (save or skip), so they don't reappear.
final swipedIdsProvider = StateProvider<Set<String>>((ref) => {});

/// The swipe deck: cars matching the HOME feed filter (same source of truth as
/// the list view), minus the ones already swiped this session.
final swipeDeckProvider = Provider<List<CarModel>>((ref) {
  final filtered = ref.watch(filteredCarsProvider).valueOrNull ?? const [];
  final swiped = ref.watch(swipedIdsProvider);
  return filtered.where((c) => !swiped.contains(c.id)).toList();
});
