// The unread rule decides what the bell badge and the notifications screen
// show. Getting it wrong either hides real messages or re-invents the fake
// notifications this replaced, so it is pinned here.

import 'package:flutter_test/flutter_test.dart';

import 'package:otov/data/models/chat_model.dart';

const me = 'me';
const them = 'them';

final _sent = DateTime(2026, 8, 2, 12, 0);

/// [noMessages] rather than a null [lastMessageAt], because a nullable
/// parameter can't tell "not supplied" from "deliberately null".
ChatModel _chat({
  DateTime? lastMessageAt,
  bool noMessages = false,
  String lastSenderId = them,
  Map<String, DateTime> lastRead = const {},
}) {
  return ChatModel(
    id: 'car1_me',
    participants: const [me, them],
    buyerId: me,
    sellerId: them,
    carId: 'car1',
    carTitle: 'מאזדה CX-5',
    carPhoto: '',
    lastMessage: 'עדיין זמין?',
    lastMessageAt: noMessages ? null : (lastMessageAt ?? _sent),
    createdAt: DateTime(2026, 8, 1),
    lastSenderId: lastSenderId,
    lastRead: lastRead,
  );
}

void main() {
  group('ChatModel.isUnreadFor', () {
    test('a message from the other party that was never opened is unread', () {
      expect(_chat().isUnreadFor(me), isTrue);
    });

    test('my own message is never unread for me', () {
      expect(_chat(lastSenderId: me).isUnreadFor(me), isFalse);
    });

    test('opened after the message arrived is read', () {
      final chat = _chat(
        lastRead: {me: _sent.add(const Duration(minutes: 1))},
      );
      expect(chat.isUnreadFor(me), isFalse);
    });

    test('opened before the message arrived is still unread', () {
      final chat = _chat(
        lastRead: {me: _sent.subtract(const Duration(hours: 3))},
      );
      expect(chat.isUnreadFor(me), isTrue);
    });

    test('the other side having read it does not clear it for me', () {
      final chat = _chat(
        lastRead: {them: _sent.add(const Duration(minutes: 1))},
      );
      expect(chat.isUnreadFor(me), isTrue);
    });

    test('an empty chat is not unread', () {
      expect(_chat(noMessages: true).isUnreadFor(me), isFalse);
    });

    test('a chat from before sender tracking is treated as read', () {
      // Otherwise every conversation that already existed would announce
      // itself as new the moment this shipped.
      expect(_chat(lastSenderId: '').isUnreadFor(me), isFalse);
    });
  });
}
