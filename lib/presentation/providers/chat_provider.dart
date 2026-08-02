import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/car_model.dart';
import '../../data/models/chat_model.dart';
import '../../data/models/message_model.dart';
import '../../data/repositories/chat_repository.dart';
import 'auth_provider.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

/// Chats for the signed-in user (empty if not signed in).
final userChatsProvider = StreamProvider<List<ChatModel>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(<ChatModel>[]);
  return ref.watch(chatRepositoryProvider).streamUserChats(user.uid);
});

/// Chats with a message the signed-in user hasn't opened yet, newest first.
/// This is the whole of the notifications feed — there is no other real
/// event source on the free plan, and inventing one is how the screen ended
/// up showing three notifications that never happened.
final unreadChatsProvider = Provider<List<ChatModel>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const [];
  final chats = ref.watch(userChatsProvider).valueOrNull ?? const [];
  return chats.where((c) => c.isUnreadFor(uid)).toList();
});

/// Badge count for the bell on the home screen.
final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(unreadChatsProvider).length;
});

/// Marks a chat as read for the signed-in user.
final markChatReadProvider = Provider<Future<void> Function(String)>((ref) {
  return (chatId) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    await ref
        .read(chatRepositoryProvider)
        .markRead(chatId: chatId, uid: user.uid);
  };
});

/// The chat document for a given chatId.
final chatProvider =
    FutureProvider.family<ChatModel?, String>((ref, chatId) async {
  return ref.watch(chatRepositoryProvider).getChat(chatId);
});

/// Live messages for a given chatId.
final messagesProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, chatId) {
  return ref.watch(chatRepositoryProvider).streamMessages(chatId);
});

/// Ensures a chat exists for [car] and returns its chatId. Returns null if the
/// user isn't signed in.
final openChatForCarProvider =
    Provider<Future<String?> Function(CarModel car)>((ref) {
  return (car) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return null;
    final chat = await ref
        .read(chatRepositoryProvider)
        .ensureChat(car: car, buyerId: user.uid);
    return chat.id;
  };
});

/// Sends a message in [chatId]. No-op if not signed in or text is blank.
final sendMessageProvider =
    Provider<Future<void> Function(String chatId, String text)>((ref) {
  return (chatId, text) async {
    final user = ref.read(authStateProvider).valueOrNull;
    final trimmed = text.trim();
    if (user == null || trimmed.isEmpty) return;
    await ref.read(chatRepositoryProvider).sendMessage(
          chatId: chatId,
          senderId: user.uid,
          text: trimmed,
        );
  };
});
