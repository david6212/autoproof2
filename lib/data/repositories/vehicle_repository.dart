import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/vehicle.dart';
import '../models/vehicle_reminder.dart';

/// Reads and writes for the private vehicle passports (`vehicles`) and their
/// reminders.
///
/// Service records are deliberately NOT here — they live in
/// [ServiceRepository], which exposes no update or delete. Keeping them in a
/// separate class is what stops an ordinary-looking `updateVehicle` from ever
/// growing a path into the immutable history.
class VehicleRepository {
  VehicleRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _vehicles =>
      _db.collection('vehicles');

  CollectionReference<Map<String, dynamic>> _reminders(String vehicleId) =>
      _vehicles.doc(vehicleId).collection('reminders');

  /// Plates are stored digits-only so the same car is one car whether it was
  /// typed with dashes or without.
  static String normalisePlate(String plate) =>
      plate.replaceAll(RegExp(r'[^0-9]'), '');

  // ---- Vehicles ----

  /// The signed-in owner's garage, newest first.
  Stream<List<Vehicle>> watchMyVehicles(String uid) {
    // Sorted client-side so no composite (ownerId + createdAt) index is needed.
    return _vehicles.where('ownerId', isEqualTo: uid).snapshots().map((snap) {
      final list = [
        for (final d in snap.docs) Vehicle.fromFirestore(d.data(), d.id),
      ];
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<Vehicle?> watchVehicle(String vehicleId) =>
      _vehicles.doc(vehicleId).snapshots().map(
            (d) => d.exists && d.data() != null
                ? Vehicle.fromFirestore(d.data()!, d.id)
                : null,
          );

  Future<Vehicle?> getVehicle(String vehicleId) async {
    final snap = await _vehicles.doc(vehicleId).get();
    if (!snap.exists || snap.data() == null) return null;
    return Vehicle.fromFirestore(snap.data()!, snap.id);
  }

  /// Whether this owner already has this plate in their garage. Two passports
  /// for one car would split its history, which defeats the point.
  Future<Vehicle?> findMyVehicleByPlate(String uid, String plate) async {
    final snap = await _vehicles
        .where('ownerId', isEqualTo: uid)
        .where('plate', isEqualTo: normalisePlate(plate))
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    return Vehicle.fromFirestore(d.data(), d.id);
  }

  /// Creates a passport and returns its id.
  ///
  /// `serviceCount` starts at 0 and the rules require it — a vehicle cannot be
  /// created claiming a history it never accumulated here.
  Future<String> createVehicle({
    required String ownerId,
    required String plate,
    String nickname = '',
    Map<String, dynamic>? govSnapshot,
    int currentKm = 0,
    DateTime? purchaseDate,
    int? purchasePrice,
  }) async {
    final now = DateTime.now();
    final vehicle = Vehicle(
      id: '',
      plate: normalisePlate(plate),
      ownerId: ownerId,
      nickname: nickname,
      govSnapshot: govSnapshot,
      govFetchedAt: govSnapshot != null ? now : null,
      currentKm: currentKm,
      purchaseDate: purchaseDate,
      purchasePrice: purchasePrice,
      createdAt: now,
    );
    final ref = await _vehicles.add(vehicle.toFirestore());
    return ref.id;
  }

  /// Points a passport at a listing that already exists.
  ///
  /// The publish-from-passport flow does this in its own batch. This is the
  /// other direction: somebody published the ordinary way and now wants to
  /// document what they have done to the car, so the passport is created
  /// afterwards and attached to the listing already on the market.
  Future<void> attachToListing(String vehicleId, String carId) =>
      _vehicles.doc(vehicleId).update({
        'isListed': true,
        'activeCarId': carId,
      });

  Future<void> updateNickname(String vehicleId, String nickname) =>
      _vehicles.doc(vehicleId).update({'nickname': nickname.trim()});

  /// Stores the result of an open-recall check, with the time it was made.
  ///
  /// Both together: the timestamp alone would let a throttled check mean
  /// "showed nothing", which an owner reads as "no recalls" — the one wrong
  /// answer this can give.
  Future<void> markRecallChecked(String vehicleId, int openCount) =>
      _vehicles.doc(vehicleId).update({
        'lastRecallCheckAt': DateTime.now(),
        'openRecallCount': openCount,
      });

  /// Removes a passport — **only while it holds no history.**
  ///
  /// Once even one service record exists the vehicle cannot be deleted, here
  /// or in the rules. Otherwise "delete the car and add it again" would be a
  /// way to erase an inconvenient record, and the append-only guarantee would
  /// be decorative.
  Future<void> deleteEmptyVehicle(String vehicleId) async {
    final v = await getVehicle(vehicleId);
    if (v == null) return;
    if (v.serviceCount > 0) {
      throw StateError('לא ניתן למחוק רכב שיש לו רשומות טיפול');
    }
    await _vehicles.doc(vehicleId).delete();
  }

  // ---- Reminders ----

  Stream<List<VehicleReminder>> watchReminders(String vehicleId) =>
      _reminders(vehicleId).snapshots().map((snap) {
        final list = [
          for (final d in snap.docs)
            VehicleReminder.fromFirestore(d.data(), d.id),
        ];
        list.sort((a, b) {
          final ad = a.dueDate, bd = b.dueDate;
          if (ad == null && bd == null) return 0;
          if (ad == null) return 1; // undated reminders sink
          if (bd == null) return -1;
          return ad.compareTo(bd);
        });
        return list;
      });

  Future<String> addReminder(String vehicleId, VehicleReminder reminder) async {
    final ref = await _reminders(vehicleId).add(reminder.toFirestore());
    return ref.id;
  }

  Future<void> setReminderDone(
    String vehicleId,
    String reminderId,
    bool isDone,
  ) =>
      _reminders(vehicleId).doc(reminderId).update({'isDone': isDone});

  Future<void> deleteReminder(String vehicleId, String reminderId) =>
      _reminders(vehicleId).doc(reminderId).delete();
}
