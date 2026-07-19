import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/car_model.dart';
import 'auth_provider.dart';
import 'cars_provider.dart';
import 'chat_provider.dart';

class SwipePrefs {
  final double maxBudget;
  final Set<String> types;
  final int minYear;

  const SwipePrefs({
    this.maxBudget = 200000,
    this.types = const {},
    this.minYear = 2010,
  });

  SwipePrefs copyWith({double? maxBudget, Set<String>? types, int? minYear}) {
    return SwipePrefs(
      maxBudget: maxBudget ?? this.maxBudget,
      types: types ?? this.types,
      minYear: minYear ?? this.minYear,
    );
  }
}

final swipePrefsProvider = StateProvider<SwipePrefs>((ref) => const SwipePrefs());

/// Cars already swiped this session (like or skip), so they don't reappear.
final processedIdsProvider = StateProvider<Set<String>>((ref) => {});

/// Active cars matching the prefs and not yet swiped.
final swipeCandidatesProvider = Provider<List<CarModel>>((ref) {
  final cars = ref.watch(activeCarsProvider).valueOrNull ?? const [];
  final prefs = ref.watch(swipePrefsProvider);
  final processed = ref.watch(processedIdsProvider);
  return cars
      .where((c) =>
          !processed.contains(c.id) &&
          c.price <= prefs.maxBudget &&
          c.year >= prefs.minYear)
      .toList();
});

/// Info about the most recent match, shown on MatchScreen.
class MatchInfo {
  final CarModel car;
  final String chatId;
  const MatchInfo({required this.car, required this.chatId});
}

final lastMatchProvider = StateProvider<MatchInfo?>((ref) => null);

/// Likes a car; returns true if it produced a match (and sets lastMatch).
final likeCarProvider = Provider<Future<bool> Function(CarModel)>((ref) {
  return (car) async {
    ref.read(processedIdsProvider.notifier).update((s) => {...s, car.id});

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return false;

    final isMatch =
        await ref.read(carRepositoryProvider).likeCar(car.id, user.uid);
    if (isMatch) {
      final chatId = await ref.read(openChatForCarProvider).call(car);
      if (chatId != null) {
        ref.read(lastMatchProvider.notifier).state =
            MatchInfo(car: car, chatId: chatId);
      }
      return chatId != null;
    }
    return false;
  };
});

/// Skips a car (in-memory only).
final skipCarProvider = Provider<void Function(CarModel)>((ref) {
  return (car) {
    ref.read(processedIdsProvider.notifier).update((s) => {...s, car.id});
  };
});
