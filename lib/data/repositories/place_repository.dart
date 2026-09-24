import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/place.dart';
import '../models/place_review.dart';
import 'operator_inbox_repository.dart';

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
  /// [includeHidden] is for the operator, who has to see a hidden review to be
  /// able to restore it. Everyone else never receives one in the list.
  Stream<List<PlaceReview>> watchReviews(String placeId,
          {bool includeHidden = false}) =>
      _places.doc(placeId).collection('reviews').snapshots().map((snap) {
        final list = [
          for (final d in snap.docs) PlaceReview.fromFirestore(d.data(), d.id),
        ]..removeWhere((r) => r.hiddenByOperator && !includeHidden);
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

    // A hidden review's rating was taken out of the aggregate when it was
    // hidden. Taking it out a second time would lower the garage's score for a
    // review that no longer counts — so a hidden review is simply deleted.
    if (data['hiddenByOperator'] == true) {
      await reviewRef.delete();
      return;
    }

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

  /// "This review is false or defamatory."
  ///
  /// The document id ends in the reporter's uid, so the rules can refuse a
  /// second report from the same account: it arrives as an update, and only
  /// the operator may update a report. Returns false when this person has
  /// already reported this review, so the screen can say so rather than
  /// pretend a duplicate was filed.
  Future<bool> reportReview({
    required String placeId,
    required String reviewUid,
    required String reporterUid,
    String reason = '',
  }) async {
    final ref = _db
        .collection('review_reports')
        .doc('${placeId}__${reviewUid}__$reporterUid');
    if ((await ref.get()).exists) return false;
    await ref.set(unansweredReport({
      'placeId': placeId,
      'reviewUid': reviewUid,
      'reporterUid': reporterUid,
      'note': reason.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    }));
    return true;
  }

  /// Hides a reported review — **hides, not deletes**.
  ///
  /// The words stay exactly as written. If the report turns out to be wrong,
  /// the review comes back intact; if it turns out to be defamatory, the text
  /// is still there as the record of what was published. Deleting would
  /// destroy the one thing both outcomes need.
  ///
  /// Its rating leaves the aggregate in the same batch. A report usually says
  /// the review is not legitimate, and a hidden one-star that still drags the
  /// garage's score down would be moderation in name only.
  Future<void> hideReview({
    required String placeId,
    required String reviewUid,
  }) =>
      _setHidden(placeId: placeId, reviewUid: reviewUid, hidden: true);

  /// Restores a hidden review, and puts its rating back.
  Future<void> restoreReview({
    required String placeId,
    required String reviewUid,
  }) =>
      _setHidden(placeId: placeId, reviewUid: reviewUid, hidden: false);

  Future<void> _setHidden({
    required String placeId,
    required String reviewUid,
    required bool hidden,
  }) async {
    final placeRef = _places.doc(placeId);
    final reviewRef = placeRef.collection('reviews').doc(reviewUid);

    final review = (await reviewRef.get()).data();
    if (review == null) return;
    // Already in the state asked for: do nothing, rather than move the
    // aggregate a second time.
    if ((review['hiddenByOperator'] == true) == hidden) return;
    final rating = (review['rating'] as num?)?.toInt() ?? 0;

    final place = (await placeRef.get()).data() ?? const <String, dynamic>{};
    final oldCount = (place['ratingCount'] as num?)?.toInt() ?? 0;
    final oldSum = (place['ratingSum'] as num?)?.toInt() ?? 0;
    final count = hidden ? oldCount - 1 : oldCount + 1;
    final sum = hidden ? oldSum - rating : oldSum + rating;

    final batch = _db.batch();
    batch.update(reviewRef, {
      'hiddenByOperator': hidden,
      'hiddenAt': hidden ? FieldValue.serverTimestamp() : null,
    });
    batch.update(placeRef, {
      'ratingCount': count < 0 ? 0 : count,
      'ratingSum': sum < 0 ? 0 : sum,
      'ratingAvg': count <= 0 ? 0 : sum / count,
    });
    await batch.commit();
  }

  /// Everything in one category, newest first, hidden entries excluded.
  Future<List<Place>> byCategory(PlaceCategory category, {int limit = 20}) async {
    final snap = await _places
        .where('category', isEqualTo: category.id)
        .where('isHidden', isEqualTo: false)
        .limit(limit)
        .get();

    final list = [
      for (final d in snap.docs) Place.fromFirestore(d.data(), d.id),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// How many people have said this place does not exist, and whether the
  /// reader is one of them.
  Future<({int count, bool mine})> reportState(
      String placeId, String? uid) async {
    final snap = await _places.doc(placeId).collection('reports').get();
    return (
      count: snap.docs.length,
      mine: uid != null && snap.docs.any((d) => d.id == uid),
    );
  }

  /// Files a report, and hides the place once three people have filed one.
  ///
  /// **The hiding happens on the device that files the third report**, because
  /// this plan has no server to do it. That is a real limitation and it shapes
  /// the design: the threshold is deliberately low enough to be useful and
  /// high enough that one person cannot act alone, and the report is keyed by
  /// uid so nobody can reach three by themselves.
  ///
  /// Hiding is not deleting. The place, its reviews and its reports all stay;
  /// it simply stops appearing. Nothing here can be undone by a client, which
  /// is why three strangers are required to do it.
  Future<void> reportDoesNotExist({
    required String placeId,
    required String uid,
    String reason = 'not_exists',
  }) async {
    final placeRef = _places.doc(placeId);
    final reportRef = placeRef.collection('reports').doc(uid);

    await reportRef.set({
      'reason': reason,
      'reporterUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Counted after the write, so the reporter's own report is included and
    // the third person to file is the one who acts on it.
    final reports = await placeRef.collection('reports').get();
    if (reports.docs.length >= 3) {
      await placeRef.update({'isHidden': true});
    }
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
