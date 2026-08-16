/// A car someone used to own, kept privately under their own user document.
///
/// This exists because the obvious way to build "רכבים שהיו בבעלותי" cannot
/// work. A passport is readable only by its current owner, so once the car
/// changes hands the previous owner loses sight of it — correctly. And the
/// transfers collection cannot be queried at all: listing it is denied,
/// because the document ids ARE the handover codes and a list would hand them
/// out.
///
/// So the record is written at sale time, to the seller's own private
/// subcollection. It is a keepsake, not a live view: it says what the car was
/// and what was logged on it, frozen at the moment it was handed over. It
/// cannot show what the new owner did next, and it should not.
class PastVehicle {
  final String id; // the vehicle id it was made from
  final String plate;
  final String title; // "סקודה אוקטביה"
  final int servicesLogged;
  final DateTime? ownedFrom;
  final DateTime soldAt;

  const PastVehicle({
    required this.id,
    required this.plate,
    required this.title,
    this.servicesLogged = 0,
    this.ownedFrom,
    required this.soldAt,
  });

  /// How long they had it, in whole months. Null when the start is unknown —
  /// a vehicle added without a purchase date has no honest answer here.
  int? get ownedMonths {
    final from = ownedFrom;
    if (from == null) return null;
    return soldAt.difference(from).inDays ~/ 30;
  }

  factory PastVehicle.fromFirestore(Map<String, dynamic> data, String id) {
    return PastVehicle(
      id: id,
      plate: data['plate'] ?? '',
      title: data['title'] ?? '',
      servicesLogged: (data['servicesLogged'] ?? 0) is int
          ? (data['servicesLogged'] ?? 0)
          : int.tryParse('${data['servicesLogged']}') ?? 0,
      ownedFrom: (data['ownedFrom'] as dynamic)?.toDate(),
      soldAt: (data['soldAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'plate': plate,
        'title': title,
        'servicesLogged': servicesLogged,
        'ownedFrom': ownedFrom,
        'soldAt': soldAt,
      };
}
