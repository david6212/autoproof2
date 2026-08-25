import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/service_record.dart';

/// The service history of a vehicle: add and edit, never delete.
///
/// **This class was append-only until 25/08/2026**, and the comment here used
/// to say no edit method would ever exist. David asked for one — typos happen,
/// and the correction flow (a second record pointing at the first) was more
/// machinery than the problem needed. [updateService] is that method.
///
/// Three things hold the feature together in its place:
/// - **An edit stamps itself.** `editedAt` is set on every update and shown to
///   buyers, so an entry that changed after the fact says so.
/// - **An edit cannot change whose record it is**, or when it entered the
///   history. The security rule pins `addedByOwnerId` and `createdAt`.
/// - **[deleteService] still does not exist, and should not.** Fixing a wrong
///   figure and erasing an inconvenient service are different acts, and only
///   the first leaves something that is still a history. The rules refuse
///   deletion outright, so such a method could only fail at runtime.
///
/// `correctsServiceId` is kept: records written before editing existed carry
/// it, and dropping the field would orphan them.
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

  /// Saves the owner's changes to a record they already entered.
  ///
  /// Deliberately NOT gated on the odometer rule that [addService] enforces.
  /// The commonest edit is exactly the one that has to go down — fixing a
  /// typed 168,400 to 68,400 — and refusing it would leave the wrong figure
  /// in place.
  ///
  /// Which is why the vehicle's `currentKm` is recomputed here from every
  /// record rather than left alone: it is a denormalised copy of the highest
  /// reading, and editing the record that set it would otherwise leave the
  /// car showing a mileage no record supports.
  Future<void> updateService(String vehicleId, ServiceRecord record) async {
    // The two fields the rule pins are removed rather than rewritten with
    // the same values. A Firestore timestamp carries nanoseconds and a Dart
    // DateTime only microseconds, so a `createdAt` that has been read into the
    // model and written back is not always byte-identical to the one stored —
    // and the rule compares them exactly. `update` writes only the keys it is
    // given, so leaving them out leaves them untouched.
    final fields = record.toFirestore()
      ..remove('createdAt')
      ..remove('addedByOwnerId');

    final batch = _db.batch();
    batch.update(_services(vehicleId).doc(record.id), fields);

    final others = await _services(vehicleId).get();
    var highest = record.km;
    for (final d in others.docs) {
      if (d.id == record.id) continue;
      final km = ServiceRecord.fromFirestore(d.data(), d.id).km;
      if (km > highest) highest = km;
    }
    batch.update(_vehicle(vehicleId), {'currentKm': highest});

    await batch.commit();
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

    // A listing that is on the market right now must show the history as it
    // stands, so its denormalised copy moves with the record.
    //
    // This looks like it contradicts the rule that badge fields are frozen at
    // publish time, and it does not: freezing protects listings the passport
    // is no longer attached to, so logging a service years later cannot change
    // what an old advert claimed. While `activeCarId` points here, the advert
    // and the history are the same car being sold today.
    final activeCarId = data['activeCarId'];
    if (data['isListed'] == true && activeCarId is String) {
      final count = serviceCount + 1;
      final first = (data['firstServiceAt'] as dynamic)?.toDate() ?? record.date;
      final last = _laterOf(data['lastServiceAt'], record.date);
      batch.update(_db.collection('cars').doc(activeCarId), {
        'vehicleId': vehicleId,
        'serviceCount': count,
        'historySpanMonths': last.difference(first as DateTime).inDays ~/ 30,
        'hasDocumentedHistory':
            count >= 3 && last.difference(first).inDays ~/ 30 >= 6,
      });
    }

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
