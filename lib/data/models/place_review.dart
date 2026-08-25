/// One person's review of a garage or a car wash.
///
/// **The document id is the author's uid.** That is not a shortcut — it is
/// what makes "one review per person" a property of the database rather than a
/// rule the app remembers to follow. A second review overwrites the first, and
/// the security rule refuses a write to anyone else's id.
///
/// A review is an opinion about somebody else's business, so unlike a service
/// record it can be deleted by the person who wrote it. Nobody is owed the
/// permanence of a stranger's opinion of them.
class PlaceReview {
  /// The author's uid, and the document id.
  final String uid;

  final int rating;
  final String text;

  /// What the visit was for, in the author's words or from the service record
  /// that prompted the review.
  final String serviceType;

  /// What they paid, if they chose to say. Shekels.
  final int? costPaid;

  /// "מאזדה CX-5" — filled from the passport when the review was written from
  /// one, so a reader can weigh a review of a gearbox job on a car like theirs.
  final String vehicleModel;

  /// The passport the review came from, and the specific records it covers.
  /// Both null/empty when somebody reviews a place they simply visited.
  final String? vehicleId;
  final List<String> serviceRecordIds;

  final String authorName;
  final DateTime createdAt;
  final DateTime? editedAt;

  const PlaceReview({
    required this.uid,
    required this.rating,
    this.text = '',
    this.serviceType = '',
    this.costPaid,
    this.vehicleModel = '',
    this.vehicleId,
    this.serviceRecordIds = const [],
    required this.authorName,
    required this.createdAt,
    this.editedAt,
  });

  /// The longest a review may be. Enforced in the form, in the model and in
  /// the security rule — the rule is the one that counts.
  static const maxTextLength = 500;

  bool get wasEdited => editedAt != null;

  /// "מיכל ש." — a first name and an initial.
  ///
  /// A review is public and attached to a named business, and the author did
  /// not agree to have their full name sit under an opinion of it forever.
  String get displayName {
    final parts = authorName.trim().split(RegExp(r'\s+'))
      ..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return 'מבקר';
    if (parts.length == 1) return parts.first;
    return '${parts.first} ${parts[1].substring(0, 1)}.';
  }

  factory PlaceReview.fromFirestore(Map<String, dynamic> data, String uid) {
    int? asIntOrNull(Object? v) =>
        v == null ? null : (v is int ? v : int.tryParse('$v'));

    return PlaceReview(
      uid: uid,
      rating: (data['rating'] as num?)?.toInt() ?? 0,
      text: data['text'] ?? '',
      serviceType: data['serviceType'] ?? '',
      costPaid: asIntOrNull(data['costPaid']),
      vehicleModel: data['vehicleModel'] ?? '',
      vehicleId: data['vehicleId'],
      serviceRecordIds: [
        for (final id in (data['serviceRecordIds'] as List?) ?? const [])
          '$id',
      ],
      authorName: data['authorName'] ?? 'מבקר',
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      editedAt: (data['editedAt'] as dynamic)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'rating': rating,
        'text': text.trim(),
        'serviceType': serviceType.trim(),
        if (costPaid != null) 'costPaid': costPaid,
        'vehicleModel': vehicleModel.trim(),
        if (vehicleId != null) 'vehicleId': vehicleId,
        'serviceRecordIds': serviceRecordIds,
        'authorName': authorName,
        'createdAt': createdAt,
        if (editedAt != null) 'editedAt': editedAt,
      };
}
