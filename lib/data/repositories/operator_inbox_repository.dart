import 'package:cloud_firestore/cloud_firestore.dart';

/// Which published promise a request falls under.
enum InboxKind { correction, noteReport, reviewReport, proApplication }

extension InboxKindX on InboxKind {
  String get label => switch (this) {
        InboxKind.correction => 'בקשת תיקון',
        InboxKind.noteReport => 'דיווח על הערה',
        InboxKind.reviewReport => 'דיווח על ביקורת',
        InboxKind.proApplication => 'בקשה להצטרף כבעל מקצוע',
      };

  String get collection => switch (this) {
        InboxKind.correction => 'data_corrections',
        InboxKind.noteReport => 'note_reports',
        InboxKind.reviewReport => 'review_reports',
        InboxKind.proApplication => 'pro_applications',
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
    this.placeId,
    this.proId,
    this.claimedLicence,
    this.reviewUid,
  });

  final String id;
  final InboxKind kind;

  /// Null while the server timestamp is still resolving on a local write.
  final DateTime? createdAt;

  final String? carId;
  final String? note;

  /// The `kind` field a correction request carries — which promise it is under.
  final String? subKind;

  /// Set on a review report: which review, on which place, so the inbox can
  /// act on it directly rather than send the operator hunting for it.
  final String? placeId;
  final String? reviewUid;

  /// An escort application: whose profile it is, and the licence number they
  /// typed. The number is a claim — the operator's screen looks it up live
  /// rather than trusting what was stored.
  final String? proId;
  final String? claimedLicence;

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

  static InboxItem fromData(
    InboxKind kind,
    String id,
    Map<String, Object?> d,
  ) {
    return InboxItem(
      id: id,
      kind: kind,
      createdAt: _asDate(d['createdAt']),
      carId: d['carId'] as String?,
      note: d['note'] as String?,
      subKind: d['kind'] as String?,
      placeId: d['placeId'] as String?,
      reviewUid: d['reviewUid'] as String?,
      proId: d['proId'] as String?,
      claimedLicence: d['claimedLicence'] as String?,
    );
  }

  /// A server timestamp arrives as a `Timestamp`, and is null for the moment
  /// between the local write and the server's answer.
  static DateTime? _asDate(Object? v) =>
      v is Timestamp ? v.toDate() : v as DateTime?;
}

/// Writes a report with `handledAt: null` spelled out.
///
/// **An absent key is not the same as a null value.** Firestore does not index
/// a document for a field it does not have, so a report written without
/// `handledAt` is not returned by a query for `handledAt == null` — it is not
/// in that index at all. All three writers omitted the field and the inbox
/// asked the server exactly that question, so the inbox was empty for its
/// whole life while the reports sat there, readable and unseen.
///
/// The query no longer asks the server, so this is belt and braces. It stays
/// because a report that says in its own document that nobody has answered it
/// is also simply true, and because the next reader of these collections will
/// expect the field to be there.
Map<String, Object?> unansweredReport(Map<String, Object?> fields) => {
      ...fields,
      'handledAt': null,
    };

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
  ///
  /// **The unanswered half is decided here, not by the server.** It used to be
  /// `where('handledAt', isNull: true)`, which returns nothing for a document
  /// that has no such field — and no writer wrote one. Every report filed
  /// before this fix is still in that state, so asking the server would keep
  /// hiding them even now that new reports carry the field. Reading fifty and
  /// filtering costs a few documents and cannot silently empty itself again.
  Stream<List<InboxItem>> watch(InboxKind kind) {
    return _db
        .collection(kind.collection)
        .orderBy('createdAt')
        .limit(50)
        .snapshots()
        .map((s) => openOnly(kind, {for (final d in s.docs) d.id: d.data()}));
  }

  /// The reports nobody has answered yet, in the order they arrived.
  ///
  /// A document with no `handledAt` key and one with `handledAt: null` mean
  /// the same thing: open. That equivalence is the whole fix, so it is tested
  /// directly rather than inferred from the query's source text.
  static List<InboxItem> openOnly(
    InboxKind kind,
    Map<String, Map<String, Object?>> docs,
  ) {
    final open = <InboxItem>[];
    docs.forEach((id, data) {
      if (data['handledAt'] != null) return;
      open.add(InboxItem.fromData(kind, id, data));
    });
    return open;
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
