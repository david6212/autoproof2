import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/place.dart';

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
