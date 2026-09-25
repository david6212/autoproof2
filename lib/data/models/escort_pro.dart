/// How much of what a professional says about themselves has been checked.
///
/// **The whole feature turns on this enum.** A person offering to inspect a
/// stranger's car for money is exactly the place where "verified" is a word
/// this app must not throw around: it verifies a plate against a register, it
/// does not certify people. So there are three states, they are always
/// visible, and the weakest one is shown rather than hidden.
enum EscortVerification {
  /// A garage licence number that was found in the Ministry of Transport's
  /// register, with the garage's name, town and trade. Checked by machine,
  /// against a public register, and re-checkable by anyone.
  registryListed,

  /// A certificate the person uploaded, which the operator looked at and
  /// accepted. A human decision, with a date on it — and the only claim in
  /// this app that rests on the operator's own eyes.
  certificateChecked,

  /// Nothing was proved. What is on the profile is what the person said about
  /// themselves, and the label says so.
  selfDeclared,
}

extension EscortVerificationX on EscortVerification {
  /// Stored in Firestore. Never localise — the label is what changes.
  String get id => switch (this) {
        EscortVerification.registryListed => 'registry_listed',
        EscortVerification.certificateChecked => 'certificate_checked',
        EscortVerification.selfDeclared => 'self_declared',
      };

  /// What the chip says. Each one describes the check that ran; none of them
  /// describes the person. "בודק מוסמך" is the sentence this app cannot write.
  String get label => switch (this) {
        EscortVerification.registryListed => 'רשום במרשם המוסכים',
        EscortVerification.certificateChecked => 'תעודה נבדקה',
        EscortVerification.selfDeclared => 'לפי הצהרת בעל המקצוע',
      };

  static EscortVerification fromId(String? id) => switch (id) {
        'registry_listed' => EscortVerification.registryListed,
        'certificate_checked' => EscortVerification.certificateChecked,
        _ => EscortVerification.selfDeclared,
      };
}

/// Where a certificate stands, from the professional's side.
enum CertificateStatus { none, pending, approved, rejected }

extension CertificateStatusX on CertificateStatus {
  String get id => switch (this) {
        CertificateStatus.none => 'none',
        CertificateStatus.pending => 'pending',
        CertificateStatus.approved => 'approved',
        CertificateStatus.rejected => 'rejected',
      };

  /// Shown to the professional on their own profile, and nowhere else. A buyer
  /// never sees "rejected" — they see [EscortVerification.selfDeclared], which
  /// is the true statement about what is known.
  String get ownerLabel => switch (this) {
        CertificateStatus.none => 'לא הועלתה תעודה',
        CertificateStatus.pending => 'התעודה ממתינה לבדיקה',
        CertificateStatus.approved => 'התעודה נבדקה ואושרה',
        CertificateStatus.rejected => 'התעודה לא אושרה',
      };

  static CertificateStatus fromId(String? id) => switch (id) {
        'pending' => CertificateStatus.pending,
        'approved' => CertificateStatus.approved,
        'rejected' => CertificateStatus.rejected,
        _ => CertificateStatus.none,
      };
}

/// Somebody who will come with a buyer to look at a car, for a price they set.
///
/// **Not an inspection institute, and the wording never lets it become one.**
/// A licensed `מכון בדיקה` is a regulated business; this is a person who knows
/// engines agreeing to stand next to one. The app calls it ליווי, shows what
/// has and has not been checked about them, and stays out of the money.
class EscortPro {
  const EscortPro({
    required this.id,
    required this.displayName,
    required this.town,
    required this.areas,
    required this.priceIls,
    this.about = '',
    this.yearsExperience = 0,
    this.claimedLicence,
    this.garageLicence,
    this.garageName,
    this.garageTown,
    this.certStatus = CertificateStatus.none,
    this.certCheckedAt,
    this.declaresInsurance = false,
    this.isHidden = false,
    this.ratingCount = 0,
    this.ratingSum = 0,
    required this.createdAt,
  });

  final String id;

  /// A first name and an initial, as they typed it. Not an identity check —
  /// nothing here proves who this person is, and the profile says so.
  final String displayName;
  final String town;

  /// Towns or regions they are willing to travel to.
  final List<String> areas;

  /// What they charge, in whole shekels, paid directly to them. **No money
  /// moves through this app** — see `EscortRepository` for why that is a rule
  /// and not an omission.
  final int priceIls;

  final String about;
  final int yearsExperience;

  /// The licence number as the applicant typed it. **A claim, never a badge.**
  ///
  /// It is here and separate because of what this app runs on: Spark, no
  /// server, so the rules are the only enforcement — and a rule cannot call
  /// the Ministry's API to see whether a number is real. If the client wrote
  /// the verified field itself, every applicant could hand themselves the
  /// register's badge by typing eight digits.
  ///
  /// So the applicant writes this, the operator's inbox looks the number up
  /// live and shows what the register answers, and approving writes the trio
  /// below. Nothing on a buyer's screen is ever drawn from this field.
  final String? claimedLicence;

  /// A Ministry of Transport garage licence number that was looked up and
  /// accepted. The three garage fields are written together or not at all,
  /// by the operator only — the rules refuse them from anybody else.
  final String? garageLicence;
  final String? garageName;
  final String? garageTown;

  final CertificateStatus certStatus;
  final DateTime? certCheckedAt;

  /// Their own statement that they carry professional liability cover. A
  /// declaration, shown as one — we hold no policy and check nothing.
  final bool declaresInsurance;

  final bool isHidden;
  final int ratingCount;
  final int ratingSum;
  final DateTime createdAt;

  /// Derived, never read from the document — the same rule as a garage's
  /// rating. A field a client could write is a field somebody would.
  EscortVerification get verification {
    if ((garageLicence ?? '').isNotEmpty) {
      return EscortVerification.registryListed;
    }
    if (certStatus == CertificateStatus.approved) {
      return EscortVerification.certificateChecked;
    }
    return EscortVerification.selfDeclared;
  }

  /// The line under the chip: what exactly was checked, in words. An icon
  /// alone would leave the reader to guess, and guessing upward is the whole
  /// risk here.
  String get verificationDetail => switch (verification) {
        EscortVerification.registryListed =>
          'רישיון מס\' $garageLicence · $garageName'
              '${(garageTown ?? '').isEmpty ? '' : ' · $garageTown'}',
        EscortVerification.certificateChecked =>
          'תעודת מקצוע שהוצגה ונבדקה'
              '${certCheckedAt == null ? '' : ' · ${certCheckedAt!.month.toString().padLeft(2, '0')}/${certCheckedAt!.year}'}',
        EscortVerification.selfDeclared =>
          'לא הוצגה תעודה ולא נמצא רישיון מוסך',
      };

  double get ratingAvg => ratingCount <= 0 ? 0 : ratingSum / ratingCount;

  /// Below this a rating is a couple of opinions, not a score — the same floor
  /// the garage directory uses, for the same reason.
  static const minRatingsToShow = 3;

  bool get hasEnoughRatings => ratingCount >= minRatingsToShow;

  factory EscortPro.fromFirestore(Map<String, dynamic> data, String id) {
    int asInt(Object? v) => v is int ? v : int.tryParse('${v ?? 0}') ?? 0;

    return EscortPro(
      id: id,
      displayName: '${data['displayName'] ?? ''}',
      town: '${data['town'] ?? ''}',
      areas: [for (final a in (data['areas'] as List?) ?? const []) '$a'],
      priceIls: asInt(data['priceIls']),
      about: '${data['about'] ?? ''}',
      yearsExperience: asInt(data['yearsExperience']),
      claimedLicence: data['claimedLicence'] as String?,
      garageLicence: data['garageLicence'] as String?,
      garageName: data['garageName'] as String?,
      garageTown: data['garageTown'] as String?,
      certStatus: CertificateStatusX.fromId(data['certStatus'] as String?),
      certCheckedAt: (data['certCheckedAt'] as dynamic)?.toDate(),
      declaresInsurance: data['declaresInsurance'] == true,
      isHidden: data['isHidden'] == true,
      ratingCount: asInt(data['ratingCount']),
      ratingSum: asInt(data['ratingSum']),
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  /// What a professional may write about themselves.
  ///
  /// **The checked fields are not in here, and that is the point.** The garage
  /// licence trio, the certificate's status and date, the hidden flag and the
  /// aggregates are all absent: the rules refuse them from a client, and the
  /// only writer is the operator or the register lookup on the server side of
  /// the apply call. A profile that could set its own badge would be a profile
  /// that always had one.
  Map<String, dynamic> toFirestore() => {
        'displayName': displayName,
        'town': town,
        'areas': areas,
        'priceIls': priceIls,
        'about': about,
        'yearsExperience': yearsExperience,
        'declaresInsurance': declaresInsurance,
        if ((claimedLicence ?? '').isNotEmpty) 'claimedLicence': claimedLicence,
      };
}
