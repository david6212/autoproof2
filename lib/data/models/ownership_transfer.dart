import 'dart:math';

enum TransferStatus { pending, claimed, expired }

/// A handover of a vehicle passport from one owner to the next.
///
/// **The document id IS the claim code.** That is not a shortcut, it is the
/// security model: without a server there is nothing to check a code against,
/// so the code has to be the thing you need in order to find the document at
/// all. The rules allow `get` by id and forbid `list`, which means a signed-in
/// stranger cannot enumerate pending transfers and cannot discover a code they
/// were not given. Storing the code as a field as well would undo that.
///
/// The seller reads the code off their screen and hands it over; the buyer
/// types it in. Two weeks to use it, then it is dead.
class OwnershipTransfer {
  /// Characters that survive being read aloud and retyped: no O/0, no I/1,
  /// no Q. A code exchanged by voice at a parking lot has to be unambiguous.
  static const _alphabet = 'ABCDEFGHJKLMNPRSTUVWXYZ23456789';

  static const codeLength = 6;
  static const validFor = Duration(days: 14);

  final String id; // == the claim code
  final String plate;
  final String vehicleId;
  final String fromUserId;
  final String? toUserId; // empty until claimed
  final String? carId; // the listing it was sold from, when there was one
  final TransferStatus status;
  final DateTime createdAt;
  final DateTime? claimedAt;
  final DateTime expiresAt;

  /// How many service records travel with the car. Shown to both sides so the
  /// handover states plainly what is being passed on.
  final int servicesCarried;

  /// The car's name, copied here at creation.
  ///
  /// It has to live on this document because the buyer cannot read the vehicle
  /// itself — a passport is readable only by its owner, and until the code is
  /// claimed that is still the seller. Without this the buyer would be
  /// confirming a handover of something the screen could not name.
  final String vehicleTitle;

  const OwnershipTransfer({
    required this.id,
    required this.plate,
    required this.vehicleId,
    required this.fromUserId,
    this.toUserId,
    this.carId,
    this.status = TransferStatus.pending,
    required this.createdAt,
    this.claimedAt,
    required this.expiresAt,
    this.servicesCarried = 0,
    this.vehicleTitle = '',
  });

  String get claimCode => id;

  bool get isExpired =>
      status == TransferStatus.expired || DateTime.now().isAfter(expiresAt);

  bool get isClaimable => status == TransferStatus.pending && !isExpired;

  /// A fresh claim code. Uses [Random.secure] — a guessable code is a car
  /// history handed to a stranger.
  static String generateCode() {
    final rnd = Random.secure();
    return String.fromCharCodes([
      for (var i = 0; i < codeLength; i++)
        _alphabet.codeUnitAt(rnd.nextInt(_alphabet.length)),
    ]);
  }

  /// Normalises what the buyer typed: uppercase, no spaces or dashes.
  static String normaliseCode(String input) =>
      input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  factory OwnershipTransfer.fromFirestore(
      Map<String, dynamic> data, String id) {
    return OwnershipTransfer(
      id: id,
      plate: data['plate'] ?? '',
      vehicleId: data['vehicleId'] ?? '',
      fromUserId: data['fromUserId'] ?? '',
      toUserId: data['toUserId'],
      carId: data['carId'],
      status: TransferStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => TransferStatus.pending,
      ),
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      claimedAt: (data['claimedAt'] as dynamic)?.toDate(),
      expiresAt: (data['expiresAt'] as dynamic)?.toDate() ??
          DateTime.now().add(validFor),
      servicesCarried: (data['servicesCarried'] ?? 0) is int
          ? (data['servicesCarried'] ?? 0)
          : int.tryParse('${data['servicesCarried']}') ?? 0,
      vehicleTitle: data['vehicleTitle'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'plate': plate,
        'vehicleId': vehicleId,
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'carId': carId,
        'status': status.name,
        'createdAt': createdAt,
        'claimedAt': claimedAt,
        'expiresAt': expiresAt,
        'servicesCarried': servicesCarried,
        'vehicleTitle': vehicleTitle,
      };
}
