class ChatModel {
  final String id;
  final List<String> participants;
  final String buyerId;
  final String sellerId;
  final String carId;
  final String carTitle;
  final String carPhoto;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final DateTime createdAt;

  const ChatModel({
    required this.id,
    required this.participants,
    required this.buyerId,
    required this.sellerId,
    required this.carId,
    required this.carTitle,
    required this.carPhoto,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.createdAt,
  });

  factory ChatModel.fromFirestore(Map<String, dynamic> data, String id) {
    return ChatModel(
      id: id,
      participants: List<String>.from(data['participants'] ?? const []),
      buyerId: data['buyerId'] ?? '',
      sellerId: data['sellerId'] ?? '',
      carId: data['carId'] ?? '',
      carTitle: data['carTitle'] ?? '',
      carPhoto: data['carPhoto'] ?? '',
      lastMessage: data['lastMessage'] ?? '',
      lastMessageAt: (data['lastMessageAt'] as dynamic)?.toDate(),
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'participants': participants,
        'buyerId': buyerId,
        'sellerId': sellerId,
        'carId': carId,
        'carTitle': carTitle,
        'carPhoto': carPhoto,
        'lastMessage': lastMessage,
        'lastMessageAt': lastMessageAt,
        'createdAt': createdAt,
      };

  /// The other participant's id relative to [me].
  String otherParticipant(String me) =>
      me == buyerId ? sellerId : buyerId;
}
