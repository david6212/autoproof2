/// How a vehicle entered the owner's garage.
enum AcquiredVia {
  manual, // the owner added a car they already had
  bonnetcheck, // bought through the app, inherited with its history
}

/// A car in someone's private garage — the "passport".
///
/// This is deliberately NOT a listing. A listing ([CarModel]) is public and
/// exists to be sold; a vehicle is private to its owner and exists to be lived
/// with. A vehicle can produce a listing (and points at it through
/// [activeCarId]) but it outlives every listing made from it, which is the
/// whole point: the service history has to survive the sale to be worth
/// anything to the next buyer.
class Vehicle {
  final String id;
  final String plate; // normalised: digits only, no dashes
  final String ownerId;
  final String nickname; // "האוטו של אמא"
  final Map<String, dynamic>? govSnapshot; // copied at add time
  final DateTime? govFetchedAt;

  /// Highest odometer reading ever recorded on this vehicle.
  ///
  /// Only advanced by ordinary service records — a correction record does not
  /// move it. That means a typo'd high reading stays until a later real
  /// service overtakes it. Accepted for now: the alternative is recomputing a
  /// max across the whole timeline on every write, and a reading that is too
  /// high is the safe direction to be wrong in (it can only block an entry,
  /// never invent mileage the car has not done).
  final int currentKm;

  final DateTime? purchaseDate;
  final int? purchasePrice;
  final AcquiredVia acquiredVia;
  final String? previousOwnerId; // the ownership chain
  final DateTime? transferredAt;

  /// The handover code this vehicle was claimed with, written by the buyer at
  /// claim time. The security rules read it back to verify the claim, so it is
  /// not decoration — without it an ownership change is refused.
  final String? claimedVia;

  final bool isListed;
  final String? activeCarId; // → cars/{id}

  // Denormalised from the services subcollection so the garage list and the
  // "תיק מתועד" badge cost no extra reads.
  final int serviceCount;
  final DateTime? firstServiceAt;
  final DateTime? lastServiceAt;

  /// Last time open recalls were checked for this plate. Throttles the check
  /// to once a day — the dataset does not change faster than that.
  final DateTime? lastRecallCheckAt;

  final DateTime createdAt;

  const Vehicle({
    required this.id,
    required this.plate,
    required this.ownerId,
    this.nickname = '',
    this.govSnapshot,
    this.govFetchedAt,
    this.currentKm = 0,
    this.purchaseDate,
    this.purchasePrice,
    this.acquiredVia = AcquiredVia.manual,
    this.previousOwnerId,
    this.transferredAt,
    this.claimedVia,
    this.isListed = false,
    this.activeCarId,
    this.serviceCount = 0,
    this.firstServiceAt,
    this.lastServiceAt,
    this.lastRecallCheckAt,
    required this.createdAt,
  });

  /// How long the documented history spans, in whole months.
  int get historySpanMonths {
    final first = firstServiceAt;
    final last = lastServiceAt;
    if (first == null || last == null) return 0;
    return last.difference(first).inDays ~/ 30;
  }

  /// The "תיק מתועד" badge: at least 3 records spanning at least 6 months.
  ///
  /// Both halves matter. Three receipts entered on the same evening say
  /// nothing about how the car was kept; three spread over half a year say
  /// someone has been logging it as they go. The badge is a statement about
  /// the existence of records, never about the condition of the car.
  bool get hasDocumentedHistory => serviceCount >= 3 && historySpanMonths >= 6;

  /// Whether an open-recall check is due (never checked, or over a day ago).
  bool get needsRecallCheck {
    final last = lastRecallCheckAt;
    if (last == null) return true;
    return DateTime.now().difference(last).inHours >= 24;
  }

  /// Display name — the nickname if the owner gave one, otherwise the model.
  String titleWith(String fallback) =>
      nickname.trim().isNotEmpty ? nickname.trim() : fallback;

  factory Vehicle.fromFirestore(Map<String, dynamic> data, String id) {
    return Vehicle(
      id: id,
      plate: data['plate'] ?? '',
      ownerId: data['ownerId'] ?? '',
      nickname: data['nickname'] ?? '',
      govSnapshot: (data['govSnapshot'] as Map?)?.cast<String, dynamic>(),
      govFetchedAt: (data['govFetchedAt'] as dynamic)?.toDate(),
      currentKm: (data['currentKm'] ?? 0) is int
          ? (data['currentKm'] ?? 0)
          : int.tryParse('${data['currentKm']}') ?? 0,
      purchaseDate: (data['purchaseDate'] as dynamic)?.toDate(),
      purchasePrice: data['purchasePrice'] == null
          ? null
          : (data['purchasePrice'] is int
              ? data['purchasePrice']
              : int.tryParse('${data['purchasePrice']}')),
      acquiredVia: AcquiredVia.values.firstWhere(
        (v) => v.name == data['acquiredVia'],
        orElse: () => AcquiredVia.manual,
      ),
      previousOwnerId: data['previousOwnerId'],
      transferredAt: (data['transferredAt'] as dynamic)?.toDate(),
      claimedVia: data['claimedVia'],
      isListed: data['isListed'] == true,
      activeCarId: data['activeCarId'],
      serviceCount: (data['serviceCount'] ?? 0) is int
          ? (data['serviceCount'] ?? 0)
          : int.tryParse('${data['serviceCount']}') ?? 0,
      firstServiceAt: (data['firstServiceAt'] as dynamic)?.toDate(),
      lastServiceAt: (data['lastServiceAt'] as dynamic)?.toDate(),
      lastRecallCheckAt: (data['lastRecallCheckAt'] as dynamic)?.toDate(),
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'plate': plate,
        'ownerId': ownerId,
        'nickname': nickname,
        'govSnapshot': govSnapshot,
        'govFetchedAt': govFetchedAt,
        'currentKm': currentKm,
        'purchaseDate': purchaseDate,
        'purchasePrice': purchasePrice,
        'acquiredVia': acquiredVia.name,
        'previousOwnerId': previousOwnerId,
        'transferredAt': transferredAt,
        'claimedVia': claimedVia,
        'isListed': isListed,
        'activeCarId': activeCarId,
        'serviceCount': serviceCount,
        'firstServiceAt': firstServiceAt,
        'lastServiceAt': lastServiceAt,
        'lastRecallCheckAt': lastRecallCheckAt,
        'createdAt': createdAt,
      };
}
