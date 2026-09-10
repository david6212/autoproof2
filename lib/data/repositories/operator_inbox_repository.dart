import 'package:cloud_firestore/cloud_firestore.dart';

/// Which published promise a request falls under.
enum InboxKind { correction, noteReport }

extension InboxKindX on InboxKind {
  String get label => switch (this) {
        InboxKind.correction => 'בקשת תיקון',
        InboxKind.noteReport => 'דיווח על הערה',
      };

  String get collection => switch (this) {
        InboxKind.correction => 'data_corrections',
        InboxKind.noteReport => 'note_reports',
      };
}

/// One thing somebody asked for and is owed an answer to.
class InboxItem {
  const InboxItem({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.carId,
    this.note,
    this.subKind,
  });

  final String id;
  final InboxKind kind;

  /// Null while the server timestamp is still resolving on a local write.
  final DateTime? createdAt;

  final String? carId;
  final String? note;

  /// The `kind` field a correction request carries — which promise it is under.
  final String? subKind;

  /// How long the person has been waiting. Null until the timestamp lands.
  int? daysWaiting(DateTime now) {
    final at = createdAt;
    if (at == null) return null;
    return DateTime(now.year, now.month, now.day)
        .difference(DateTime(at.year, at.month, at.day))
        .inDays;
  }

  /// The published promise is fourteen days. Seven is where it stops being
  /// comfortable — a request flagged only on day fourteen is a request already
  /// answered late.
  bool isUrgent(DateTime now) => (daysWaiting(now) ?? 0) >= 7;

  static InboxItem fromDoc(
    InboxKind kind,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    return InboxItem(
      id: doc.id,
      kind: kind,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      carId: d['carId'] as String?,
      note: d['note'] as String?,
      subKind: d['kind'] as String?,
    );
  }
}

/// The requests the operator has promised to answer.
///
/// **This exists because the promise had no delivery.** The privacy policy, the
/// content-removal policy and the complaints procedure all say
/// *"נשיב תוך 14 ימים"*, and both collections behind that sentence were
/// `allow read: if false` — unreadable by everyone, the operator included. A
/// request arrived and sat there until somebody remembered to open the Firebase
/// console. Failing to answer a data-subject request is an actual breach, and
/// for a product whose whole argument is that it never claims more than it
/// performs, it was the wrong promise to be leaving unkept.
///
/// There is no server on the Spark plan to send an email, so the delivery is
/// the app itself: the operator opens it anyway, and open requests are on the
/// profile screen where they cannot be missed.
class OperatorInboxRepository {
  OperatorInboxRepository(this._db);

  final FirebaseFirestore _db;

  /// Unanswered requests of one kind, oldest first — because the oldest is the
  /// one closest to breaking the fourteen days.
  Stream<List<InboxItem>> watch(InboxKind kind) {
    return _db
        .collection(kind.collection)
        .where('handledAt', isNull: true)
        .orderBy('createdAt')
        .limit(50)
        .snapshots()
        .map((s) => [for (final d in s.docs) InboxItem.fromDoc(kind, d)]);
  }

  /// Marks one answered. Writes a timestamp and nothing else — the rules allow
  /// only that field to change, so the account that receives complaints about
  /// this product cannot edit what they said.
  Future<void> markHandled(InboxItem item) {
    return _db
        .collection(item.kind.collection)
        .doc(item.id)
        .update({'handledAt': FieldValue.serverTimestamp()});
  }
}
