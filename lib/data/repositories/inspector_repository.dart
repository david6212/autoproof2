import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/inspector_model.dart';

class InspectorRepository {
  InspectorRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _inspectors =>
      _db.collection('inspectors');

  Stream<List<InspectorModel>> streamInspectors() {
    return _inspectors.snapshots().map((s) {
      final list = s.docs
          .map((d) => InspectorModel.fromFirestore(d.data(), d.id))
          .toList();
      // Available first, then by rating.
      list.sort((a, b) {
        if (a.available != b.available) return a.available ? -1 : 1;
        return b.rating.compareTo(a.rating);
      });
      return list;
    });
  }

  Future<InspectorModel?> getInspector(String id) async {
    final snap = await _inspectors.doc(id).get();
    if (!snap.exists || snap.data() == null) return null;
    return InspectorModel.fromFirestore(snap.data()!, id);
  }

  /// Creates a booking (payment charged only after inspection — escrow).
  Future<void> createBooking({
    required String inspectorId,
    required String carId,
    required String buyerId,
    required List<String> topics,
    required int amount,
  }) async {
    await _db.collection('bookings').add({
      'inspectorId': inspectorId,
      'carId': carId,
      'buyerId': buyerId,
      'topics': topics,
      'amount': amount,
      'status': 'pending',
      'createdAt': DateTime.now(),
    });
  }
}
