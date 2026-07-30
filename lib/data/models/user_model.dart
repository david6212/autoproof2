enum UserRole { buyer, seller, inspector }

class UserModel {
  final String uid;
  final String name;
  final String phone;
  final UserRole role;
  final bool verified;
  final double rating;
  final DateTime createdAt;
  final List<String> fcmTokens;

  /// Whether a phone number is attached. Required before publishing a listing —
  /// Google and Apple sign-in leave this empty.
  bool get hasPhone => phone.trim().isNotEmpty;

  const UserModel({
    required this.uid,
    required this.name,
    required this.phone,
    required this.role,
    required this.verified,
    required this.rating,
    required this.createdAt,
    this.fcmTokens = const [],
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == data['role'],
        orElse: () => UserRole.buyer,
      ),
      verified: data['verified'] ?? false,
      rating: (data['rating'] ?? 0.0).toDouble(),
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      fcmTokens: List<String>.from(data['fcmTokens'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'phone': phone,
        'role': role.name,
        'verified': verified,
        'rating': rating,
        'createdAt': createdAt,
        'fcmTokens': fcmTokens,
      };

  UserModel copyWith({
    String? name,
    String? phone,
    UserRole? role,
    bool? verified,
    double? rating,
    List<String>? fcmTokens,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      verified: verified ?? this.verified,
      rating: rating ?? this.rating,
      createdAt: createdAt,
      fcmTokens: fcmTokens ?? this.fcmTokens,
    );
  }
}
