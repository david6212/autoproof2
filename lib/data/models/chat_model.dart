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

  /// Who sent [lastMessage]. Empty on chats created before this was tracked.
  final String lastSenderId;

  /// When each participant last opened the chat, keyed by uid. Absent for a
  /// participant who has never opened it.
  final Map<String, DateTime> lastRead;

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
    this.lastSenderId = '',
    this.lastRead = const {},
  });

  /// Whether [uid] has an unread message waiting.
  ///
  /// Deliberately conservative: a chat whose last message predates this
  /// feature has no [lastSenderId], and is treated as read rather than
  /// announcing old conversations as new.
  bool isUnreadFor(String uid) {
    final at = lastMessageAt;
    if (at == null || lastSenderId.isEmpty || lastSenderId == uid) {
      return false;
    }
    final seen = lastRead[uid];
    return seen == null || seen.isBefore(at);
  }

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
      lastSenderId: data['lastSenderId'] ?? '',
      lastRead: ((data['lastRead'] as Map?) ?? const {}).map(
        (k, v) => MapEntry('$k', (v as dynamic).toDate() as DateTime),
      ),
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
        'lastSenderId': lastSenderId,
        'lastRead': lastRead,
      };

  /// The other participant's id relative to [me].
  String otherParticipant(String me) =>
      me == buyerId ? sellerId : buyerId;
}
