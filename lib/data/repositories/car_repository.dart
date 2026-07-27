import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/car_model.dart';
import '../models/car_note_model.dart';

/// All reads/writes for the cars collection and per-user saved cars.
class CarRepository {
  CarRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _cars => _db.collection('cars');

  CollectionReference<Map<String, dynamic>> _saved(String uid) =>
      _db.collection('users').doc(uid).collection('saved');

  /// Stream of active listings, newest first.
  Stream<List<CarModel>> streamActiveCars() {
    // Sort client-side to avoid needing a composite (status + createdAt) index.
    return _cars
        .where('status', isEqualTo: CarStatus.active.name)
        .snapshots()
        .map((snap) {
      final cars = snap.docs
          .map((d) => CarModel.fromFirestore(d.data(), d.id))
          .toList();
      cars.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return cars;
    });
  }

  Future<CarModel?> getCarById(String id) async {
    final snap = await _cars.doc(id).get();
    if (!snap.exists || snap.data() == null) return null;
    return CarModel.fromFirestore(snap.data()!, snap.id);
  }

  /// RULE 2 — a seller may have at most one active listing.
  Future<bool> hasActiveListing(String sellerId) async {
    final q = await _cars
        .where('sellerId', isEqualTo: sellerId)
        .where('status', isEqualTo: CarStatus.active.name)
        .limit(1)
        .get();
    return q.docs.isNotEmpty;
  }

  /// Creates a listing and returns its new id.
  Future<String> createListing(CarModel car) async {
    final ref = await _cars.add(car.toFirestore());
    return ref.id;
  }

  Future<void> updateStatus(String carId, CarStatus status) {
    return _cars.doc(carId).update({'status': status.name});
  }

  Future<void> updatePhotos(String carId, List<String> photos) {
    return _cars.doc(carId).update({'photos': photos});
  }

  /// Records a buyer's "like" on a car and returns whether it's a mutual match.
  /// A match occurs when the seller has already liked this buyer, or when the
  /// car is flagged `demoMatch: true` (used to demo the flow without Cloud
  /// Functions on the free plan).
  Future<bool> likeCar(String carId, String buyerId) async {
    await _cars
        .doc(carId)
        .collection('buyer_likes')
        .doc(buyerId)
        .set({'likedAt': FieldValue.serverTimestamp()});

    final carSnap = await _cars.doc(carId).get();
    final demoMatch = carSnap.data()?['demoMatch'] == true;

    final sellerLike = await _cars
        .doc(carId)
        .collection('seller_likes')
        .doc(buyerId)
        .get();

    return demoMatch || sellerLike.exists;
  }

  /// Adds an anonymous review. IMPORTANT: no sellerId field — the seller
  /// cannot query or read reviews (RULE 6).
  Future<void> addReview({
    required String carId,
    required String reviewerId,
    required bool anonymous,
    required List<String> reasons,
    required String text,
  }) async {
    await _db.collection('reviews').add({
      'carId': carId,
      'reviewerId': anonymous ? '' : reviewerId,
      'anonymous': anonymous,
      'reasons': reasons,
      'text': text,
      'createdAt': DateTime.now(),
    });
  }

  // ---- Visitor notes (public, per listing) ----

  CollectionReference<Map<String, dynamic>> _notes(String carId) =>
      _cars.doc(carId).collection('notes');

  /// Stream of visitor notes for a car, newest first.
  Stream<List<CarNote>> streamNotes(String carId) {
    return _notes(carId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CarNote.fromFirestore(d.data(), d.id))
            .toList());
  }

  Future<void> addNote({
    required String carId,
    required String authorUid,
    required String authorName,
    required String text,
    String sellerFlag = '',
  }) {
    return _notes(carId).add(CarNote(
      id: '',
      authorUid: authorUid,
      authorName: authorName,
      text: text,
      createdAt: DateTime.now(),
      sellerFlag: sellerFlag,
    ).toFirestore());
  }

  /// Deletes a note. Security rules ensure only its author can.
  Future<void> deleteNote(String carId, String noteId) {
    return _notes(carId).doc(noteId).delete();
  }

  /// Flags a note for admin review (e.g. defamatory / off-topic content).
  Future<void> reportNote({
    required String carId,
    required String noteId,
    required String reporterUid,
  }) {
    return _db.collection('note_reports').add({
      'carId': carId,
      'noteId': noteId,
      'reporterUid': reporterUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ---- Buyer journey progress (private, per buyer + car) ----

  DocumentReference<Map<String, dynamic>> _journey(String carId, String uid) =>
      _cars.doc(carId).collection('journeys').doc(uid);

  /// Stream of the buyer's current stage for a car. Defaults to 1 (the gov-data
  /// check counts as done, so the physical inspection is the first live step).
  Stream<int> streamJourneyStage(String carId, String uid) {
    return _journey(carId, uid).snapshots().map((snap) {
      final stage = snap.data()?['stage'];
      return stage is int ? stage : 1;
    });
  }

  Future<void> setJourneyStage(String carId, String uid, int stage) {
    return _journey(carId, uid).set({
      'stage': stage,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---- Saved cars ----

  Stream<Set<String>> streamSavedIds(String uid) {
    return _saved(uid)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  Stream<List<CarModel>> streamSavedCars(String uid) {
    return _saved(uid).snapshots().asyncMap((snap) async {
      final ids = snap.docs.map((d) => d.id).toList();
      if (ids.isEmpty) return <CarModel>[];
      final futures = ids.map(getCarById);
      final cars = await Future.wait(futures);
      return cars.whereType<CarModel>().toList();
    });
  }

  Future<void> toggleSaved(String uid, String carId, bool save) {
    final doc = _saved(uid).doc(carId);
    return save
        ? doc.set({'savedAt': FieldValue.serverTimestamp()})
        : doc.delete();
  }
}
