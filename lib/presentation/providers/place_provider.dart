import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/place.dart';
import '../../data/repositories/place_repository.dart';

final placeRepositoryProvider =
    Provider<PlaceRepository>((ref) => PlaceRepository());

/// Suggestions for what the user has typed into the garage field.
///
/// `autoDispose` and keyed by the query string, so Riverpod caches each
/// keystroke's result for as long as the field is open and re-uses it when
/// somebody backspaces — which they do constantly, and which would otherwise
/// be a fresh pair of Firestore reads per character.
final placeSearchProvider =
    FutureProvider.autoDispose.family<List<Place>, String>((ref, query) {
  // Keep a result alive briefly after the widget stops watching it. Without
  // this, every keystroke disposes the previous provider and a backspace pays
  // full price again.
  final link = ref.keepAlive();
  Future<void>.delayed(const Duration(seconds: 30), link.close);

  return ref.watch(placeRepositoryProvider).search(query);
});

/// One place, for a service record that carries a `placeId`.
final placeByIdProvider =
    FutureProvider.autoDispose.family<Place?, String>((ref, placeId) {
  return ref.watch(placeRepositoryProvider).byId(placeId);
});
