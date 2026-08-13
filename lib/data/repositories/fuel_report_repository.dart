import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/fuel_report.dart';

/// Driver-reported diesel prices, one document per reporter per station.
///
/// Kept separate from [CarRepository] because it has nothing to do with a
/// listing — a fuel report belongs to a station, and stations come from the
/// government dataset, not from Firestore.
class FuelReportRepository {
  FuelReportRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _reports(String stationId) =>
      _db.collection('fuel_reports').doc(stationId).collection('reports');

  /// Live tally for one station.
  Stream<FuelPriceTally> streamTally(String stationId, String? myUid) {
    return _reports(stationId)
        .orderBy('at', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) {
      final reports = <FuelReport>[];
      int? mine;
      for (final doc in snap.docs) {
        final d = doc.data();
        final agorot = (d['agorot'] as num?)?.toInt();
        // A server timestamp is null for the instant between the local write
        // and the server ack; such a doc is simply not counted yet.
        final at = (d['at'] as Timestamp?)?.toDate();
        if (agorot == null || at == null) continue;
        if (!FuelReport.isPlausible(agorot)) continue;
        reports.add(FuelReport(uid: doc.id, agorot: agorot, at: at));
        if (myUid != null && doc.id == myUid) mine = agorot;
      }
      return FuelPriceTally(reports: reports, myAgorot: mine);
    });
  }

  /// The newest tallies for many stations at once, for sorting the list by
  /// price. One collection-group query instead of 1,255 listeners.
  ///
  /// Returns station id → median agorot, fresh reports only.
  Future<Map<String, int>> recentMedians() async {
    final cutoff = DateTime.now().subtract(FuelPriceTally.freshness);
    final snap = await _db
        .collectionGroup('reports')
        .where('at', isGreaterThan: Timestamp.fromDate(cutoff))
        .get();

    final byStation = <String, List<int>>{};
    for (final doc in snap.docs) {
      final agorot = (doc.data()['agorot'] as num?)?.toInt();
      if (agorot == null || !FuelReport.isPlausible(agorot)) continue;
      // .../fuel_reports/{stationId}/reports/{uid}
      final stationId = doc.reference.parent.parent?.id;
      if (stationId == null) continue;
      byStation.putIfAbsent(stationId, () => []).add(agorot);
    }

    return {
      for (final e in byStation.entries)
        e.key: _median(e.value..sort()),
    };
  }

  static int _median(List<int> sorted) {
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }

  /// Records (or replaces) this user's report for a station.
  Future<void> report({
    required String stationId,
    required String uid,
    required int agorot,
  }) {
    if (!FuelReport.isPlausible(agorot)) {
      throw ArgumentError('price out of range');
    }
    return _reports(stationId).doc(uid).set({
      'agorot': agorot,
      'at': FieldValue.serverTimestamp(),
    });
  }

  /// Lets a driver take their own report back — the same right the app gives
  /// for notes and encounters.
  Future<void> remove({required String stationId, required String uid}) =>
      _reports(stationId).doc(uid).delete();
}
