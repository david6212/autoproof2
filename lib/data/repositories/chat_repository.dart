import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/car_model.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

/// Real-time chat backed by Firestore.
///
/// A chat is deterministically keyed by "{carId}_{buyerId}" so each buyer has
/// exactly one conversation per car, and both parties reference the same doc.
class ChatRepository {
  ChatRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection('chats');

  CollectionReference<Map<String, dynamic>> _messages(String chatId) =>
      _chats.doc(chatId).collection('messages');

  static String chatIdFor(String carId, String buyerId) => '${carId}_$buyerId';

  /// Ensures a chat exists between the buyer and the car's seller.
  Future<ChatModel> ensureChat({
    required CarModel car,
    required String buyerId,
  }) async {
    final id = chatIdFor(car.id, buyerId);
    final ref = _chats.doc(id);
    final snap = await ref.get();
    if (snap.exists && snap.data() != null) {
      return ChatModel.fromFirestore(snap.data()!, id);
    }

    final chat = ChatModel(
      id: id,
      participants: [buyerId, car.sellerId],
      buyerId: buyerId,
      sellerId: car.sellerId,
      carId: car.id,
      carTitle: car.title,
      carPhoto: car.coverPhoto ?? '',
      lastMessage: '',
      lastMessageAt: null,
      createdAt: DateTime.now(),
    );
    await ref.set(chat.toFirestore());
    return chat;
  }

  Future<ChatModel?> getChat(String chatId) async {
    final snap = await _chats.doc(chatId).get();
    if (!snap.exists || snap.data() == null) return null;
    return ChatModel.fromFirestore(snap.data()!, chatId);
  }

  Stream<List<MessageModel>> streamMessages(String chatId) {
    return _messages(chatId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs
            .map((d) => MessageModel.fromFirestore(d.data(), d.id))
            .toList());
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
  }) async {
    final now = DateTime.now();
    await _messages(chatId).add(
      MessageModel(id: '', senderId: senderId, text: text, createdAt: now)
          .toFirestore(),
    );
    await _chats.doc(chatId).update({
      'lastMessage': text,
      'lastMessageAt': now,
      'lastSenderId': senderId,
      // Sending counts as reading: the sender must never see their own
      // message come back as an unread notification.
      'lastRead.$senderId': now,
    });
  }

  /// Records that [uid] has seen everything in the chat. Best-effort — a
  /// failure here must never stop the conversation from opening.
  Future<void> markRead({required String chatId, required String uid}) async {
    try {
      await _chats.doc(chatId).update({'lastRead.$uid': DateTime.now()});
    } catch (_) {
      // Offline, or a chat the user can no longer access. Nothing to do.
    }
  }

  /// Chats the user participates in, most recent first (sorted client-side to
  /// avoid a composite index).
  Stream<List<ChatModel>> streamUserChats(String uid) {
    return _chats
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((s) {
      final chats = s.docs
          .map((d) => ChatModel.fromFirestore(d.data(), d.id))
          .toList();
      chats.sort((a, b) {
        final at = a.lastMessageAt ?? a.createdAt;
        final bt = b.lastMessageAt ?? b.createdAt;
        return bt.compareTo(at);
      });
      return chats;
    });
  }
}
