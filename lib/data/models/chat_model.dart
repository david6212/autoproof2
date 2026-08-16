import 'message_model.dart';

/// Firestore hands these back as a map of uid to Timestamp; every one of the
/// three has the same shape, and an absent map means nobody has done it yet.
Map<String, DateTime> _stamps(dynamic raw) {
  if (raw is! Map) return const {};
  final out = <String, DateTime>{};
  raw.forEach((k, v) {
    if (v == null) return;
    if (v is DateTime) {
      out['$k'] = v;
      return;
    }
    // A Firestore Timestamp, normally. Anything else is a document written by
    // something that should not have written it — skip that one entry rather
    // than throw, because this parser runs inside the chat-list stream and an
    // exception there fails every row instead of one.
    try {
      final t = (v as dynamic).toDate();
      if (t is DateTime) out['$k'] = t;
    } catch (_) {
      // Not a timestamp. Treated as "never happened", which is the safe
      // reading: an unparseable lastRead shows a message as unread, not as
      // read by somebody who never opened it.
    }
  });
  return out;
}

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

  /// When each participant's app last pulled this chat down, keyed by uid.
  ///
  /// Separate from [lastRead] because arriving and being read are different
  /// events: this one is written by the recipient's chat LIST, before they
  /// open anything.
  final Map<String, DateTime> deliveredAt;

  /// When each participant hid this chat from their own list.
  ///
  /// Hiding is per person. Removing a conversation from your list must not
  /// remove it from the other side's — their copy is theirs, and a chat is a
  /// record of something you both did.
  final Map<String, DateTime> hiddenAt;

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
    this.deliveredAt = const {},
    this.hiddenAt = const {},
  });

  /// Whether this chat should stay out of [uid]'s list.
  ///
  /// A new message brings it back, which is what people expect: hiding is
  /// tidying up a finished conversation, not blocking someone.
  bool isHiddenFor(String uid) {
    final hidden = hiddenAt[uid];
    if (hidden == null) return false;
    final at = lastMessageAt;
    return at == null || !at.isAfter(hidden);
  }

  /// How far a message of mine, sent at [sentAt], has got with [otherUid].
  MessageStatus statusOf(DateTime sentAt, String otherUid) {
    final read = lastRead[otherUid];
    if (read != null && !read.isBefore(sentAt)) return MessageStatus.read;
    final got = deliveredAt[otherUid];
    if (got != null && !got.isBefore(sentAt)) return MessageStatus.delivered;
    return MessageStatus.sent;
  }


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
      deliveredAt: _stamps(data['deliveredAt']),
      hiddenAt: _stamps(data['hiddenAt']),
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      lastSenderId: data['lastSenderId'] ?? '',
      lastRead: _stamps(data['lastRead']),
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
        'deliveredAt': deliveredAt,
        'hiddenAt': hiddenAt,
      };

  /// The other participant's id relative to [me].
  String otherParticipant(String me) =>
      me == buyerId ? sellerId : buyerId;
}
