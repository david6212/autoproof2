enum ServiceType {
  routine,
  repair,
  tires,
  brakes,
  timingBelt,
  test,
  insurance,
  other,
}

extension ServiceTypeX on ServiceType {
  String get label => switch (this) {
        ServiceType.routine => 'טיפול תקופתי',
        ServiceType.repair => 'תיקון',
        ServiceType.tires => 'צמיגים',
        ServiceType.brakes => 'בלמים',
        ServiceType.timingBelt => 'רצועת תזמון',
        ServiceType.test => 'טסט',
        ServiceType.insurance => 'ביטוח',
        ServiceType.other => 'אחר',
      };
}

/// One entry in a vehicle's service history.
///
/// **Append-only, and that is the entire feature.** A record cannot be edited
/// and cannot be deleted — not by the owner, not by anyone. It is enforced in
/// three places on purpose: the security rules refuse `update` and `delete`,
/// [ServiceRepository] exposes no method that could attempt either, and the UI
/// offers no button for it. A log its owner can quietly rewrite is worth
/// nothing to the next buyer, so the immutability *is* the product.
///
/// A mistake is fixed by adding a correction record pointing at the original
/// through [correctsServiceId]. The wrong entry stays visible. That is the
/// honest behaviour: the reader sees that something was corrected, and when.
class ServiceRecord {
  final String id;
  final ServiceType type;
  final String title; // "טיפול 60,000"
  final DateTime date;
  final int km;
  final int cost; // shekels
  final String? garageName;
  final String? notes;
  final String? receiptUrl; // Firebase Storage

  /// Who entered it. Kept across ownership transfer so a buyer can tell which
  /// records came from which owner, and so a past owner keeps read access to
  /// what they themselves wrote.
  final String addedByOwnerId;

  final DateTime createdAt;

  /// Set when this record corrects an earlier one.
  final String? correctsServiceId;

  /// When the owner last changed this record, or null if they never have.
  ///
  /// Records became editable on David's instruction, because typos happen and
  /// the correction flow was more machinery than the problem needed. This
  /// field is the price of that: a buyer reading the history is told which
  /// entries were changed after the fact, and when. An editable log that does
  /// not say so is a log that quietly rewrote itself.
  final DateTime? editedAt;

  const ServiceRecord({
    required this.id,
    required this.type,
    required this.title,
    required this.date,
    required this.km,
    this.cost = 0,
    this.garageName,
    this.notes,
    this.receiptUrl,
    required this.addedByOwnerId,
    required this.createdAt,
    this.correctsServiceId,
    this.editedAt,
  });

  bool get isCorrection => correctsServiceId != null;

  bool get wasEdited => editedAt != null;

  /// The same record with the caller's changes and a fresh edit stamp. The
  /// three fields it refuses to take are the ones that decide whose record
  /// this is and when it entered the history.
  ServiceRecord edited({
    required ServiceType type,
    required String title,
    required DateTime date,
    required int km,
    required int cost,
    String? garageName,
    String? notes,
    required DateTime at,
  }) =>
      ServiceRecord(
        id: id,
        type: type,
        title: title,
        date: date,
        km: km,
        cost: cost,
        garageName: garageName,
        notes: notes,
        receiptUrl: receiptUrl,
        addedByOwnerId: addedByOwnerId,
        createdAt: createdAt,
        correctsServiceId: correctsServiceId,
        editedAt: at,
      );

  factory ServiceRecord.fromFirestore(Map<String, dynamic> data, String id) {
    return ServiceRecord(
      id: id,
      type: ServiceType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => ServiceType.other,
      ),
      title: data['title'] ?? '',
      date: (data['date'] as dynamic)?.toDate() ?? DateTime.now(),
      km: (data['km'] ?? 0) is int
          ? (data['km'] ?? 0)
          : int.tryParse('${data['km']}') ?? 0,
      cost: (data['cost'] ?? 0) is int
          ? (data['cost'] ?? 0)
          : int.tryParse('${data['cost']}') ?? 0,
      garageName: data['garageName'],
      notes: data['notes'],
      receiptUrl: data['receiptUrl'],
      addedByOwnerId: data['addedByOwnerId'] ?? '',
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      correctsServiceId: data['correctsServiceId'],
      editedAt: (data['editedAt'] as dynamic)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'type': type.name,
        'title': title,
        'date': date,
        'km': km,
        'cost': cost,
        'garageName': garageName,
        'notes': notes,
        'receiptUrl': receiptUrl,
        'addedByOwnerId': addedByOwnerId,
        'createdAt': createdAt,
        'correctsServiceId': correctsServiceId,
        // Only when it has been edited. A key present on every record would
        // make "was this changed?" a question about null rather than about
        // presence, and the security rule reads the same field.
        if (editedAt != null) 'editedAt': editedAt,
      };
}
