import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/car_model.dart';
import '../models/ownership_transfer.dart';
import '../models/past_vehicle.dart';
import '../models/vehicle.dart';

/// Handing a vehicle passport to its next owner.
///
/// There is no server here, so the handover is two writes by two different
/// people, minutes or days apart: the seller creates a code, the buyer spends
/// it. Each half is a batch, and the security rules — not this class — are
/// what stop the buyer forging the half they control.
class TransferRepository {
  TransferRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _transfers =>
      _db.collection('transfers');

  DocumentReference<Map<String, dynamic>> _vehicle(String id) =>
      _db.collection('vehicles').doc(id);

  /// Marks a car sold and mints the handover code, in one write.
  ///
  /// The seller does all three parts — closing the listing, releasing the
  /// passport, creating the transfer — because the buyer is not allowed to
  /// touch someone else's listing. An earlier design had the buyer set the car
  /// to sold at claim time; the rules refuse it, and inside a batch one refusal
  /// fails everything, so the whole handover would silently never work.
  ///
  /// Returns the code to read out to the buyer.
  Future<String> createTransfer({
    required Vehicle vehicle,
    String? carId,
    String vehicleTitle = '',
  }) async {
    final code = await _unusedCode();
    final now = DateTime.now();

    final transfer = OwnershipTransfer(
      id: code,
      plate: vehicle.plate,
      vehicleId: vehicle.id,
      fromUserId: vehicle.ownerId,
      carId: carId,
      createdAt: now,
      expiresAt: now.add(OwnershipTransfer.validFor),
      servicesCarried: vehicle.serviceCount,
      vehicleTitle: vehicleTitle,
    );

    final batch = _db.batch();
    batch.set(_transfers.doc(code), transfer.toFirestore());
    batch.update(_vehicle(vehicle.id), {
      'isListed': false,
      'activeCarId': null,
    });
    if (carId != null) {
      batch.update(_db.collection('cars').doc(carId), {
        'status': CarStatus.sold.name,
      });
    }

    // The seller's own keepsake, written now because it cannot be recovered
    // later: once the buyer claims the code, the passport stops being readable
    // to the person who kept it.
    batch.set(
      _db
          .collection('users')
          .doc(vehicle.ownerId)
          .collection('past_vehicles')
          .doc(vehicle.id),
      PastVehicle(
        id: vehicle.id,
        plate: vehicle.plate,
        title: vehicleTitle,
        servicesLogged: vehicle.serviceCount,
        ownedFrom: vehicle.purchaseDate ?? vehicle.createdAt,
        soldAt: now,
      ).toFirestore(),
    );

    await batch.commit();
    return code;
  }

  /// Cars this user has handed on, newest first.
  Stream<List<PastVehicle>> watchPastVehicles(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('past_vehicles')
      .snapshots()
      .map((snap) {
        final list = [
          for (final d in snap.docs) PastVehicle.fromFirestore(d.data(), d.id),
        ];
        list.sort((a, b) => b.soldAt.compareTo(a.soldAt));
        return list;
      });

  /// A code no pending transfer is already using.
  ///
  /// 30^6 is about 700 million, so a collision is vanishingly unlikely — but
  /// the document id IS the code, and a blind `set` on a collision would
  /// overwrite somebody else's live handover. Three tries and then give up
  /// loudly rather than quietly destroy one.
  Future<String> _unusedCode() async {
    for (var i = 0; i < 3; i++) {
      final code = OwnershipTransfer.generateCode();
      final existing = await _transfers.doc(code).get();
      if (!existing.exists) return code;
    }
    throw StateError('לא הצלחנו ליצור קוד מסירה. נסו שוב');
  }

  /// Looks a code up. Returns null when there is nothing there — the rules
  /// allow fetching a transfer by id and forbid listing them, so this is the
  /// only way to find one, and only someone given the code can do it.
  Future<OwnershipTransfer?> findByCode(String rawCode) async {
    final code = OwnershipTransfer.normaliseCode(rawCode);
    if (code.length != OwnershipTransfer.codeLength) return null;
    final snap = await _transfers.doc(code).get();
    if (!snap.exists || snap.data() == null) return null;
    return OwnershipTransfer.fromFirestore(snap.data()!, snap.id);
  }

  /// Spends the code: the buyer becomes the owner and the history comes with
  /// the car.
  ///
  /// Nothing is copied. The service records never move — they belong to the
  /// vehicle, and the vehicle changes hands. That is why the buyer inherits a
  /// history they can trust: it was written by someone who no longer controls
  /// it, and could not have been rewritten on the way out.
  Future<void> claim({
    required OwnershipTransfer transfer,
    required String buyerUid,
  }) async {
    if (!transfer.isClaimable) {
      throw StateError('הקוד כבר נוצל או שפג תוקפו');
    }
    if (transfer.fromUserId == buyerUid) {
      throw StateError('זה קוד המסירה שיצרתם בעצמכם');
    }

    final now = DateTime.now();
    final batch = _db.batch();

    batch.update(_transfers.doc(transfer.id), {
      'toUserId': buyerUid,
      'status': TransferStatus.claimed.name,
      'claimedAt': now,
    });

    // `claimedVia` is not bookkeeping: the security rule reads it back to find
    // the transfer and verify this claim. Without it the ownership change is
    // refused.
    batch.update(_vehicle(transfer.vehicleId), {
      'ownerId': buyerUid,
      'previousOwnerId': transfer.fromUserId,
      'claimedVia': transfer.id,
      'acquiredVia': AcquiredVia.bonnetcheck.name,
      'transferredAt': now,
      'isListed': false,
      'activeCarId': null,
    });

    await batch.commit();
  }
}
