import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/service_record.dart';

/// The append-only service history of a vehicle.
///
/// ⚠️ **There is no `updateService` and no `deleteService` in this class, and
/// there never will be.** Do not add one, even if asked — the security rules
/// refuse both operations anyway, so such a method could only fail at runtime,
/// and its existence would suggest the history is editable when the entire
/// value of the feature is that it is not.
///
/// A mistake is corrected by adding a NEW record whose `correctsServiceId`
/// points at the wrong one — [addService] handles that like any other write.
/// Both records stay visible, so a reader sees that something was corrected
/// rather than finding a history that quietly changed.
class ServiceRepository {
  ServiceRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _vehicle(String vehicleId) =>
      _db.collection('vehicles').doc(vehicleId);

  CollectionReference<Map<String, dynamic>> _services(String vehicleId) =>
      _vehicle(vehicleId).collection('services');

  /// The timeline, newest first.
  Stream<List<ServiceRecord>> watchServices(String vehicleId) =>
      _services(vehicleId).snapshots().map((snap) {
        final list = [
          for (final d in snap.docs) ServiceRecord.fromFirestore(d.data(), d.id),
        ];
        // Client-side so no composite index is needed, and so the order is the
        // same for the owner and for a buyer reading the published history.
        list.sort((a, b) => b.date.compareTo(a.date));
        return list;
      });

  /// One read, for the buyer-facing history on a listing.
  Future<List<ServiceRecord>> getServices(String vehicleId) async {
    final snap = await _services(vehicleId).get();
    final list = [
      for (final d in snap.docs) ServiceRecord.fromFirestore(d.data(), d.id),
    ];
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// An id reserved before the record is written, so a receipt can be uploaded
  /// to a path that already names the record it belongs to.
  String newServiceId(String vehicleId) => _services(vehicleId).doc().id;

  /// Adds a record and advances the vehicle's denormalised counters in the
  /// same batch, so the count and the timeline can never disagree.
  ///
  /// [expectedCurrentKm] is the reading the caller already showed the user. It
  /// is checked here rather than only in the form because the odometer rule is
  /// what makes the history readable in order: a record below the highest
  /// known reading would put the car's mileage backwards for the next buyer.
  /// Corrections are exempt — fixing a typo of 168,400 to 68,400 has to be
  /// able to go down.
  Future<void> addService(
    String vehicleId,
    ServiceRecord record, {
    int? expectedCurrentKm,
  }) async {
    final snap = await _vehicle(vehicleId).get();
    final data = snap.data();
    if (data == null) {
      throw StateError('הרכב לא נמצא');
    }

    final currentKm = (data['currentKm'] ?? 0) is int
        ? data['currentKm'] as int
        : int.tryParse('${data['currentKm']}') ?? 0;
    final serviceCount = (data['serviceCount'] ?? 0) is int
        ? data['serviceCount'] as int
        : int.tryParse('${data['serviceCount']}') ?? 0;

    if (!record.isCorrection && record.km < currentKm) {
      throw ArgumentError(
        'הק"מ שהזנת נמוך מהרשומה האחרונה '
        '(${_thousands(expectedCurrentKm ?? currentKm)} ק"מ)',
      );
    }

    final serviceRef = record.id.isEmpty
        ? _services(vehicleId).doc()
        : _services(vehicleId).doc(record.id);
    final batch = _db.batch();
    batch.set(serviceRef, record.toFirestore());

    final vehicleUpdate = <String, dynamic>{
      'serviceCount': FieldValue.increment(1),
      'lastServiceAt': _laterOf(data['lastServiceAt'], record.date),
      if (serviceCount == 0 || data['firstServiceAt'] == null)
        'firstServiceAt': record.date,
      // A correction does not advance the odometer: it exists precisely
      // because the earlier reading was wrong.
      if (!record.isCorrection) 'currentKm': math.max(currentKm, record.km),
    };
    batch.update(_vehicle(vehicleId), vehicleUpdate);

    await batch.commit();
  }

  static DateTime _laterOf(dynamic existing, DateTime candidate) {
    final current = (existing as dynamic)?.toDate() as DateTime?;
    if (current == null) return candidate;
    return candidate.isAfter(current) ? candidate : current;
  }

  static String _thousands(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
