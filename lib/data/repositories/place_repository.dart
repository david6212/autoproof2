import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/place.dart';
import '../models/place_review.dart';

/// Garages and car washes: the directory the app did not have.
///
/// **It starts empty, and that is the design.** There is no public register of
/// repair garages to seed it from — the Ministry of Transport publishes
/// inspection centres, and those already live in
/// `assets/data/inspection_centers_geo.json` with their own screen. So the
/// first person to visit a garage is the one who adds it, and until then the
/// suggestions list is genuinely blank rather than pretending otherwise.
///
/// **Nothing here promotes an entry.** A place someone typed in is
/// [PlaceSource.community] and stays that way; no method can write
/// [PlaceSource.gov], because no official list is wired in and a community
/// entry wearing an official badge is the one failure this directory cannot
/// afford.
class PlaceRepository {
  PlaceRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _places =>
      _db.collection('places');

  /// Up to [limit] matches for what the user has typed so far.
  ///
  /// **Two queries, because one cannot do it.** Firestore has no substring
  /// search:
  ///
  /// - A **prefix range** on `name` finds "מוסך כהן ובניו" from "מוסך" — the
  ///   start of the name, which is how a name is stored but not always how it
  ///   is remembered.
  /// - **`array-contains`** on `nameTokens` finds the same place from "כהן",
  ///   which is what a person actually types. It needs a whole word, so it
  ///   contributes nothing until they finish one.
  ///
  /// Together they cover the two ways people search. What neither covers is a
  /// typo or the middle of a word, and no client-side query will: that is what
  /// the "add it" row in the field is for.
  Future<List<Place>> search(String query, {int limit = 6}) async {
    final q = query.trim();
    if (q.length < 2) return const [];

    final results = <String, Place>{};

    Future<void> collect(Query<Map<String, dynamic>> query) async {
      final snap = await query.limit(limit).get();
      for (final d in snap.docs) {
        final place = Place.fromFirestore(d.data(), d.id);
        // Hidden entries are gone from every list, not merely deprioritised.
        if (!place.isHidden) results[place.id] = place;
      }
    }

    // `` is above any character that appears in a name, so the range
    // covers everything that starts with `q`.
    await collect(_places
        .orderBy('name')
        .where('name', isGreaterThanOrEqualTo: q)
        .where('name', isLessThan: '$q'));

    await collect(_places.where('nameTokens', arrayContains: q));

    final list = results.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list.take(limit).toList();
  }

  Future<Place?> byId(String placeId) async {
    final snap = await _places.doc(placeId).get();
    final data = snap.data();
    return data == null ? null : Place.fromFirestore(data, snap.id);
  }

  /// The places behind a set of service records, in one read per place.
  ///
  /// Takes ids rather than reading the records itself: the caller already has
  /// them on screen, and a repository that re-reads what its caller is holding
  /// is a second source of truth waiting to disagree.
  Future<List<Place>> byIds(Iterable<String> ids) async {
    final unique = ids.toSet().toList();
    if (unique.isEmpty) return const [];

    final docs = await Future.wait(unique.map((id) => _places.doc(id).get()));
    return [
      for (final d in docs)
        if (d.data() case final data?) Place.fromFirestore(data, d.id),
    ];
  }

  /// Whether this person has already written a review here.
  ///
  /// Asked before offering to rate: a prompt that appears again after somebody
  /// has answered it is not a prompt, it is nagging.
  Future<bool> hasReviewed(String placeId, String uid) async {
    final snap = await _places.doc(placeId).collection('reviews').doc(uid).get();
    return snap.exists;
  }

  /// The reviews on a place, newest first.
  Stream<List<PlaceReview>> watchReviews(String placeId) =>
      _places.doc(placeId).collection('reviews').snapshots().map((snap) {
        final list = [
          for (final d in snap.docs) PlaceReview.fromFirestore(d.data(), d.id),
        ];
        // Sorted here rather than in the query so no composite index is
        // needed, and so the order is identical for everyone reading it.
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  Future<PlaceReview?> myReview(String placeId, String uid) async {
    final snap =
        await _places.doc(placeId).collection('reviews').doc(uid).get();
    final data = snap.data();
    return data == null ? null : PlaceReview.fromFirestore(data, snap.id);
  }

  /// Writes a review and moves the place's aggregates in the same batch.
  ///
  /// **Both writes or neither.** A review that landed without its counters
  /// would sit under an average that does not include it, and the two would
  /// never reconcile — there is no server-side job on this plan to notice.
  ///
  /// The delta is computed from the review being replaced, not from a count of
  /// documents: replacing a 5 with a 2 must move the sum by -3 and leave the
  /// count alone, and only the old rating knows that.
  Future<void> saveReview({
    required String placeId,
    required PlaceReview review,
  }) async {
    final placeRef = _places.doc(placeId);
    final reviewRef = placeRef.collection('reviews').doc(review.uid);

    final existing = await reviewRef.get();
    final previous = existing.data();
    final isNew = previous == null;
    final oldRating = isNew ? 0 : (previous['rating'] as num?)?.toInt() ?? 0;

    final placeSnap = await placeRef.get();
    final placeData = placeSnap.data();
    if (placeData == null) throw StateError('המקום לא נמצא');
    final oldCount = (placeData['ratingCount'] as num?)?.toInt() ?? 0;
    final oldSum = (placeData['ratingSum'] as num?)?.toInt() ?? 0;

    final count = oldCount + (isNew ? 1 : 0);
    final sum = oldSum + review.rating - oldRating;

    final batch = _db.batch();
    batch.set(
      reviewRef,
      {
        ...review.toFirestore(),
        // The original stands; only an edit carries a second stamp.
        if (!isNew) 'createdAt': previous['createdAt'],
        if (!isNew) 'editedAt': DateTime.now(),
      },
    );
    batch.update(placeRef, {
      'ratingCount': count,
      'ratingSum': sum,
      'ratingAvg': count == 0 ? 0 : sum / count,
      'lastReviewAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Removes a review and takes its rating back out of the aggregates.
  Future<void> deleteReview({
    required String placeId,
    required String uid,
  }) async {
    final placeRef = _places.doc(placeId);
    final reviewRef = placeRef.collection('reviews').doc(uid);

    final existing = await reviewRef.get();
    final data = existing.data();
    if (data == null) return;
    final rating = (data['rating'] as num?)?.toInt() ?? 0;

    final placeSnap = await placeRef.get();
    final placeData = placeSnap.data() ?? const <String, dynamic>{};
    final count = ((placeData['ratingCount'] as num?)?.toInt() ?? 1) - 1;
    final sum = ((placeData['ratingSum'] as num?)?.toInt() ?? rating) - rating;

    final batch = _db.batch();
    batch.delete(reviewRef);
    batch.update(placeRef, {
      'ratingCount': count < 0 ? 0 : count,
      'ratingSum': sum < 0 ? 0 : sum,
      'ratingAvg': count <= 0 ? 0 : sum / count,
    });
    await batch.commit();
  }

  /// Adds a place somebody typed in. Returns its new id.
  ///
  /// [source] is not a parameter. Everything written here is community-added,
  /// and the security rule refuses anything else — so there is no path, in the
  /// app or around it, that mints an entry claiming to be on an official
  /// register.
  Future<String> addCommunityPlace({
    required String uid,
    required PlaceCategory category,
    required String name,
    String address = '',
    String city = '',
    double lat = 0,
    double lng = 0,
    String? phone,
  }) async {
    final place = Place(
      id: '',
      source: PlaceSource.community,
      category: category,
      name: name.trim(),
      address: address.trim(),
      city: city.trim(),
      lat: lat,
      lng: lng,
      phone: (phone ?? '').trim().isEmpty ? null : phone!.trim(),
      addedByUid: uid,
      createdAt: DateTime.now(),
    );

    final ref = await _places.add(place.toFirestore());
    return ref.id;
  }
}
