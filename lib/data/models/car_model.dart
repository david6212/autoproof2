enum CarStatus { active, removed, sold }

class CarModel {
  final String id;
  final String plate;
  final String make;
  final String model;
  final int year;
  final double price;
  final int km;
  final int hand; // number of previous owners
  final String area;
  final String sellerId;
  final CarStatus status;
  final Map<String, dynamic>? govData;
  final List<String> photos; // Storage download URLs
  final String reasonForSelling;
  final DateTime createdAt;
  final int reviewCount;

  const CarModel({
    required this.id,
    required this.plate,
    required this.make,
    required this.model,
    required this.year,
    required this.price,
    required this.km,
    required this.hand,
    required this.area,
    required this.sellerId,
    required this.status,
    this.govData,
    required this.photos,
    required this.reasonForSelling,
    required this.createdAt,
    this.reviewCount = 0,
  });

  factory CarModel.fromFirestore(Map<String, dynamic> data, String id) {
    return CarModel(
      id: id,
      plate: data['plate'] ?? '',
      make: data['make'] ?? '',
      model: data['model'] ?? '',
      year: (data['year'] ?? 0) is int
          ? (data['year'] ?? 0)
          : int.tryParse('${data['year']}') ?? 0,
      price: (data['price'] ?? 0).toDouble(),
      km: (data['km'] ?? 0) is int
          ? (data['km'] ?? 0)
          : int.tryParse('${data['km']}') ?? 0,
      hand: (data['hand'] ?? 1) is int
          ? (data['hand'] ?? 1)
          : int.tryParse('${data['hand']}') ?? 1,
      area: data['area'] ?? '',
      sellerId: data['sellerId'] ?? '',
      status: CarStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => CarStatus.active,
      ),
      govData: (data['govData'] as Map?)?.cast<String, dynamic>(),
      photos: List<String>.from(data['photos'] ?? const []),
      reasonForSelling: data['reasonForSelling'] ?? '',
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      reviewCount: (data['reviewCount'] ?? 0) is int
          ? (data['reviewCount'] ?? 0)
          : int.tryParse('${data['reviewCount']}') ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'plate': plate,
        'make': make,
        'model': model,
        'year': year,
        'price': price,
        'km': km,
        'hand': hand,
        'area': area,
        'sellerId': sellerId,
        'status': status.name,
        'govData': govData,
        'photos': photos,
        'reasonForSelling': reasonForSelling,
        'createdAt': createdAt,
        'reviewCount': reviewCount,
      };

  String get title => '$make $model'.trim();
  String? get coverPhoto => photos.isNotEmpty ? photos.first : null;
}
