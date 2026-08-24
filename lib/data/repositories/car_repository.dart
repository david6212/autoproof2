import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/car_model.dart';
import '../models/car_note_model.dart';
import '../models/plate_snapshot_model.dart';

/// All reads/writes for the cars collection and per-user saved cars.
class CarRepository {
  CarRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _cars => _db.collection('cars');

  CollectionReference<Map<String, dynamic>> _saved(String uid) =>
      _db.collection('users').doc(uid).collection('saved');

  /// How long a listing stays visible. Past this it is treated as expired and
  /// withheld everywhere, so stale personal data stops circulating.
  ///
  /// NOTE: this hides expired listings, it does not erase them. Scheduled
  /// deletion needs a server-side job (Cloud Functions / a scheduled task),
  /// which the current Firebase plan does not include — see [expiredBefore].
  static const retention = Duration(days: 730); // 24 months

  /// Cut-off date: anything created before this is expired.
  static DateTime get expiredBefore => DateTime.now().subtract(retention);

  /// Stream of active listings, newest first, excluding expired ones.
  Stream<List<CarModel>> streamActiveCars() {
    // Sort client-side to avoid needing a composite (status + createdAt) index.
    return _cars
        .where('status', isEqualTo: CarStatus.active.name)
        .snapshots()
        .map((snap) {
      final cutoff = expiredBefore;
      final cars = snap.docs
          .map((d) => CarModel.fromFirestore(d.data(), d.id))
          .where((c) => c.createdAt.isAfter(cutoff))
          .toList();
      cars.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return cars;
    });
  }

  /// Ids of listings past the retention window, for a future purge job to
  /// delete. Nothing calls this yet — it exists so the deletion path is ready.
  Future<List<String>> expiredListingIds() async {
    final snap = await _cars
        .where('createdAt', isLessThan: Timestamp.fromDate(expiredBefore))
        .get();
    return [for (final d in snap.docs) d.id];
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
  /// Creates a listing, keeping the plate out of the public document.
  ///
  /// Two writes rather than one: the listing everyone can read, and a private
  /// subdocument only the seller can. The plate is what turns a car into a
  /// named person at the registry, so it lives in the second.
  Future<String> createListing(CarModel car) async {
    final ref = await _cars.add(car.toFirestore());
    await _writePrivatePlate(ref.id, car.plate);
    return ref.id;
  }

  /// `cars/{id}/private/registry` — see `firestore.rules`. Best-effort by
  /// design: a listing that exists without it is a listing whose owner cannot
  /// refresh the registry data, which is recoverable. A listing that fails to
  /// publish because of it is not.
  Future<void> _writePrivatePlate(String carId, String plate) async {
    if (plate.isEmpty) return;
    try {
      await _cars.doc(carId).collection('private').doc('registry').set({
        'plate': plate,
      });
    } catch (_) {
      // Swallowed deliberately; see above.
    }
  }

  /// The plate behind a listing, for the seller who owns it.
  ///
  /// Returns empty for anyone else — the rules refuse the read, and that is
  /// the point rather than an error to report.
  Future<String> plateFor(String carId) async {
    try {
      final doc =
          await _cars.doc(carId).collection('private').doc('registry').get();
      return '${doc.data()?['plate'] ?? ''}';
    } catch (_) {
      return '';
    }
  }

  /// Publishes a listing straight from a vehicle passport, linking the two in
  /// one atomic write.
  ///
  /// A batch rather than two writes because the halves are only correct
  /// together: a car pointing at a vehicle that does not know it is listed
  /// would leave the buyer's service history unreadable (the rules open it on
  /// the vehicle's `isListed`), and a vehicle marked listed with no car would
  /// leave a passport that cannot be published again.
  Future<String> publishFromVehicle({
    required CarModel car,
    required String vehicleId,
  }) async {
    final carRef = _cars.doc();
    final vehicleRef = _db.collection('vehicles').doc(vehicleId);

    final batch = _db.batch();
    batch.set(carRef, car.toFirestore());
    batch.update(vehicleRef, {
      'isListed': true,
      'activeCarId': carRef.id,
    });
    await batch.commit();
    await _writePrivatePlate(carRef.id, car.plate);
    return carRef.id;
  }

  /// Takes a listing down and releases its passport, so the car can be listed
  /// again later without the vehicle being stuck as "listed".
  Future<void> closeListing({
    required String carId,
    required CarStatus status,
    String? vehicleId,
  }) async {
    final batch = _db.batch();
    batch.update(_cars.doc(carId), {'status': status.name});
    if (vehicleId != null) {
      batch.update(_db.collection('vehicles').doc(vehicleId), {
        'isListed': false,
        'activeCarId': null,
      });
    }
    await batch.commit();
  }

  Future<void> updateStatus(String carId, CarStatus status) {
    return _cars.doc(carId).update({'status': status.name});
  }

  /// Replaces the registry answer stored on a listing, and stamps the time.
  ///
  /// Only the seller can call this in practice: it needs the plate, which is
  /// theirs. The date is written in the same operation because a snapshot
  /// without one is indistinguishable from a fresh answer.
  Future<void> refreshGovSnapshot(
    String carId,
    Map<String, dynamic> snapshot,
  ) {
    return _cars.doc(carId).update({
      'govSnapshot': snapshot,
      'govCheckedAt': DateTime.now(),
    });
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
    required List<NoteTag> tags,
  }) {
    return _notes(carId).add(CarNote(
      id: '',
      authorUid: authorUid,
      authorName: authorName,
      createdAt: DateTime.now(),
      tags: tags,
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

  /// One channel for every "this is wrong" and "delete my data" request, so a
  /// user never has to hunt for how to challenge something.
  Future<void> submitCorrection({
    required String kind,
    required String reporterUid,
    String carId = '',
    String note = '',
  }) {
    return _db.collection('data_corrections').add({
      'kind': kind,
      'carId': carId,
      'reporterUid': reporterUid,
      'note': note,
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

  // ---- Plate history (cross-listing memory, keyed by plate) ----

  CollectionReference<Map<String, dynamic>> _plateSnapshots(String plate) =>
      _db.collection('plate_history').doc(plate).collection('snapshots');

  /// Records a snapshot of a listing so the same plate, relisted later by
  /// anyone, can be cross-checked. Best-effort — never blocks publishing.
  Future<void> recordPlateSnapshot({
    required String plate,
    required String carId,
    required int km,
    required double price,
    required SellerType sellerType,
    required String area,
  }) {
    return _plateSnapshots(plate).add(PlateSnapshot(
      id: '',
      carId: carId,
      km: km,
      price: price,
      sellerType: sellerType,
      area: area,
      createdAt: DateTime.now(),
    ).toFirestore());
  }

  /// All past snapshots for a plate, newest first.
  Future<List<PlateSnapshot>> getPlateHistory(String plate) async {
    final snap = await _plateSnapshots(plate)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs
        .map((d) => PlateSnapshot.fromFirestore(d.data(), d.id))
        .toList();
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
