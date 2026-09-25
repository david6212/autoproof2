import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/escort_pro.dart';
import '../models/licensed_garage.dart';
import 'gov_api_repository.dart';
import 'operator_inbox_repository.dart';

/// People who will come with a buyer to look at a car, for a price they set.
///
/// **No money moves through here, and none ever should.** Holding a buyer's
/// payment is a regulated activity, and a commission per job is the shape that
/// turns a platform into a broker under the vehicle-trade licensing law. The
/// price is a number on a profile; the payment happens between two people who
/// met on this screen. If that ever changes it is a decision with a lawyer in
/// the room, not a repository method.
///
/// **Nothing a professional writes about themselves becomes a badge.** On the
/// Spark plan there is no server, so `firestore.rules` is the whole
/// enforcement layer — and a rule cannot ask the Ministry of Transport whether
/// a licence number is real. Applicants therefore write `claimedLicence`, the
/// operator sees what the register actually answers, and only the operator can
/// write the verified fields. See [EscortPro.verification].
class EscortRepository {
  EscortRepository({
    FirebaseFirestore? firestore,
    GovApiRepository? gov,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _gov = gov;

  final FirebaseFirestore _db;
  final GovApiRepository? _gov;

  CollectionReference<Map<String, dynamic>> get _pros =>
      _db.collection('escort_pros');

  /// The people a buyer can choose from, newest first.
  ///
  /// Hidden profiles are dropped here as well as in the rules' spirit: the
  /// operator hides a profile after a complaint, and a hidden profile that
  /// still appeared in a list would make hiding decorative.
  Stream<List<EscortPro>> watchAvailable({String? area}) {
    return _pros
        .orderBy('createdAt', descending: true)
        .limit(60)
        .snapshots()
        .map((snap) {
      final all = [
        for (final d in snap.docs) EscortPro.fromFirestore(d.data(), d.id)
      ]..removeWhere((p) => p.isHidden);
      if (area == null || area.trim().isEmpty) return all;
      final needle = area.trim();
      return all
          .where((p) => p.town == needle || p.areas.contains(needle))
          .toList();
    });
  }

  Future<EscortPro?> byId(String id) async {
    final doc = await _pros.doc(id).get();
    final data = doc.data();
    return data == null ? null : EscortPro.fromFirestore(data, doc.id);
  }

  /// Applies to be listed. The document id is the applicant's uid, so one
  /// person is one profile and a second application edits the first.
  ///
  /// Two writes, deliberately: the profile, and a request in the operator's
  /// inbox carrying the same fourteen-day promise as every other request in
  /// it. A profile that appeared with no request behind it would be a queue
  /// nobody was told about.
  Future<void> apply({
    required String uid,
    required EscortPro profile,
    bool certificateUploaded = false,
  }) async {
    final batch = _db.batch();

    batch.set(
      _pros.doc(uid),
      {
        ...profile.toFirestore(),
        'certStatus': certificateUploaded
            ? CertificateStatus.pending.id
            : CertificateStatus.none.id,
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(
      _db.collection(InboxKind.proApplication.collection).doc(uid),
      unansweredReport({
        'reporterUid': uid,
        'proId': uid,
        'note': profile.displayName,
        'claimedLicence': profile.claimedLicence ?? '',
        'certificateUploaded': certificateUploaded,
        'createdAt': FieldValue.serverTimestamp(),
      }),
    );

    await batch.commit();
  }

  /// What the Ministry's register says about a licence number the applicant
  /// typed — for the operator's eyes, at the moment of deciding.
  ///
  /// Returns null when nothing matches, which is an answer and not an error:
  /// the operator approves the profile without the registry trio, and the
  /// buyer sees "לפי הצהרת בעל המקצוע".
  Future<LicensedGarage?> lookupLicence(String licence) async {
    final gov = _gov;
    final wanted = licence.trim();
    if (gov == null || wanted.isEmpty) return null;

    // The register is queried per trade; mechanics is the trade this feature
    // is about, and the number is matched exactly.
    final garages = await gov.garagesFor(GarageTrade.mechanics);
    for (final g in garages) {
      if (g.licenceNumber.trim() == wanted) return g;
    }
    return null;
  }

  /// The operator's decision. Writes the fields a client is refused.
  ///
  /// [garage] is what the register answered, or null when the number matched
  /// nothing — approving without it is legitimate and leaves the profile at
  /// "לפי הצהרת בעל המקצוע" or, with a certificate accepted, at "תעודה נבדקה".
  Future<void> decide({
    required String proId,
    required bool certificateApproved,
    LicensedGarage? garage,
  }) async {
    await _pros.doc(proId).update({
      'certStatus': certificateApproved
          ? CertificateStatus.approved.id
          : CertificateStatus.rejected.id,
      'certCheckedAt': FieldValue.serverTimestamp(),
      if (garage != null) ...{
        'garageLicence': garage.licenceNumber,
        'garageName': garage.name,
        'garageTown': garage.town,
      },
    });
  }

  /// Takes a profile out of the directory. Hiding, never deleting — the same
  /// rule the garage reviews follow: the record of what was published is what
  /// a complaint is judged against.
  Future<void> setHidden({required String proId, required bool hidden}) {
    return _pros.doc(proId).update({
      'isHidden': hidden,
      'hiddenAt': hidden ? FieldValue.serverTimestamp() : null,
    });
  }
}
