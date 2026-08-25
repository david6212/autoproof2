import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/place.dart';
import '../../data/models/place_review.dart';
import '../../data/repositories/place_repository.dart';
import 'auth_provider.dart';

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

/// The reviews on one place, live.
final placeReviewsProvider =
    StreamProvider.autoDispose.family<List<PlaceReview>, String>((ref, placeId) {
  return ref.watch(placeRepositoryProvider).watchReviews(placeId);
});

/// The current user's own review of a place, or null.
///
/// Kept separate from the list so the screen can put it first and label it
/// without hunting through the stream for a uid.
final myPlaceReviewProvider =
    FutureProvider.autoDispose.family<PlaceReview?, String>((ref, placeId) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Future.value(null);
  // Re-read whenever the list changes, so writing a review updates this too.
  ref.watch(placeReviewsProvider(placeId));
  return ref.watch(placeRepositoryProvider).myReview(placeId, uid);
});

/// Add, replace and withdraw a review.
class PlaceReviewActions {
  PlaceReviewActions(this._ref);

  final Ref _ref;

  Future<bool> save({
    required String placeId,
    required int rating,
    String text = '',
    String serviceType = '',
    int? costPaid,
    String vehicleModel = '',
    String? vehicleId,
    List<String> serviceRecordIds = const [],
  }) async {
    final user = _ref.read(authStateProvider).valueOrNull;
    if (user == null) return false;

    final profile = _ref.read(currentUserModelProvider).valueOrNull;
    final name = (profile?.name.trim().isNotEmpty ?? false)
        ? profile!.name
        : (user.displayName?.trim().isNotEmpty ?? false)
            ? user.displayName!
            : 'מבקר';

    await _ref.read(placeRepositoryProvider).saveReview(
          placeId: placeId,
          review: PlaceReview(
            uid: user.uid,
            rating: rating,
            text: text,
            serviceType: serviceType,
            costPaid: costPaid,
            vehicleModel: vehicleModel,
            vehicleId: vehicleId,
            serviceRecordIds: serviceRecordIds,
            authorName: name,
            createdAt: DateTime.now(),
          ),
        );
    return true;
  }

  Future<void> remove(String placeId) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    await _ref
        .read(placeRepositoryProvider)
        .deleteReview(placeId: placeId, uid: uid);
  }
}

final placeReviewActionsProvider =
    Provider<PlaceReviewActions>(PlaceReviewActions.new);
