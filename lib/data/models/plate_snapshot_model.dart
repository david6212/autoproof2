import 'package:cloud_firestore/cloud_firestore.dart';

import 'car_model.dart';

/// A point-in-time record of a listing for a given plate, kept in
/// plate_history/{plate}/snapshots so a car relisted later (by anyone) can be
/// cross-checked against its past — most importantly to catch odometer
/// rollback. Never stores the seller's identity (privacy: the car, not the
/// person).
class PlateSnapshot {
  final String id;
  final String carId; // the listing this snapshot came from
  final int km;
  final double price;
  final SellerType sellerType;
  final String area;
  final DateTime createdAt;

  const PlateSnapshot({
    required this.id,
    required this.carId,
    required this.km,
    required this.price,
    required this.sellerType,
    required this.area,
    required this.createdAt,
  });

  /// The same record as a plain map, for storing inside a listing.
  ///
  /// The plate is not in here and never was — this collection is keyed BY the
  /// plate, and the record itself is about the car's past prices and mileage.
  /// That is exactly why it can be copied onto a public listing: it identifies
  /// no one.
  Map<String, dynamic> toMap() => {
        'id': id,
        'carId': carId,
        'km': km,
        'price': price,
        'sellerType': sellerType.name,
        'area': area,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PlateSnapshot.fromMap(Map<String, dynamic> m) => PlateSnapshot(
        id: '${m['id'] ?? ''}',
        carId: '${m['carId'] ?? ''}',
        km: (m['km'] as num?)?.toInt() ?? 0,
        price: (m['price'] as num?)?.toDouble() ?? 0,
        sellerType: SellerType.values.firstWhere(
          (t) => t.name == m['sellerType'],
          orElse: () => SellerType.private,
        ),
        area: '${m['area'] ?? ''}',
        createdAt:
            DateTime.tryParse('${m['createdAt'] ?? ''}') ?? DateTime(1970),
      );

  factory PlateSnapshot.fromFirestore(Map<String, dynamic> data, String id) {
    return PlateSnapshot(
      id: id,
      carId: data['carId'] ?? '',
      km: (data['km'] ?? 0) is int
          ? (data['km'] ?? 0)
          : int.tryParse('${data['km']}') ?? 0,
      price: (data['price'] ?? 0).toDouble(),
      sellerType: SellerType.values.firstWhere(
        (t) => t.name == data['sellerType'],
        orElse: () => SellerType.private,
      ),
      area: data['area'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'carId': carId,
        'km': km,
        'price': price,
        'sellerType': sellerType.name,
        'area': area,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
