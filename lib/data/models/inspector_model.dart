class InspectorModel {
  final String id;
  final String name;
  final String certLevel;
  final double rating;
  final int reviewCount;
  final int price;
  final bool available;
  final String area;

  const InspectorModel({
    required this.id,
    required this.name,
    required this.certLevel,
    required this.rating,
    required this.reviewCount,
    required this.price,
    required this.available,
    required this.area,
  });

  factory InspectorModel.fromFirestore(Map<String, dynamic> data, String id) {
    return InspectorModel(
      id: id,
      name: data['name'] ?? '',
      certLevel: data['certLevel'] ?? '',
      rating: (data['rating'] ?? 0).toDouble(),
      reviewCount: (data['reviewCount'] ?? 0) is int
          ? (data['reviewCount'] ?? 0)
          : int.tryParse('${data['reviewCount']}') ?? 0,
      price: (data['price'] ?? 0) is int
          ? (data['price'] ?? 0)
          : int.tryParse('${data['price']}') ?? 0,
      available: data['available'] ?? true,
      area: data['area'] ?? '',
    );
  }
}
