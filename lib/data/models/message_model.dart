/// How far one of my own messages has got.
///
/// Only three states, and the middle one is weaker here than in WhatsApp — say
/// so rather than let people read it as the same thing. WhatsApp turns one tick
/// into two using a push notification, which reaches a phone whose app is
/// closed. BonnetCheck has no push (that needs the paid Firebase plan), so a
/// message becomes [delivered] only once the other person's app is actually
/// open. A message sitting on one tick therefore means "not seen by their
/// device yet", not "failed".
enum MessageStatus {
  /// Written to the server. Nobody has picked it up.
  sent,

  /// The recipient's app has received it, but they have not opened the chat.
  delivered,

  /// They opened the chat after it arrived.
  read,
}

class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  factory MessageModel.fromFirestore(Map<String, dynamic> data, String id) {
    return MessageModel(
      id: id,
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'senderId': senderId,
        'text': text,
        'createdAt': createdAt,
      };
}
