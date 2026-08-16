import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/data/models/chat_model.dart';
import 'package:bonnetcheck/data/models/message_model.dart';

/// Ticks and hiding are both computed from fields the chat document already
/// carries, so both are pure logic and worth pinning exactly.
void main() {
  final t0 = DateTime(2026, 8, 16, 10, 0);
  final t1 = DateTime(2026, 8, 16, 11, 0);
  final t2 = DateTime(2026, 8, 16, 12, 0);

  ChatModel chat({
    DateTime? lastMessageAt,
    String lastSenderId = 'me',
    Map<String, DateTime> read = const {},
    Map<String, DateTime> delivered = const {},
    Map<String, DateTime> hidden = const {},
  }) =>
      ChatModel(
        id: 'c1',
        participants: const ['me', 'them'],
        buyerId: 'me',
        sellerId: 'them',
        carId: 'car1',
        carTitle: 'מאזדה CX-5',
        carPhoto: '',
        lastMessage: 'שלום',
        lastMessageAt: lastMessageAt,
        createdAt: t0,
        lastSenderId: lastSenderId,
        lastRead: read,
        deliveredAt: delivered,
        hiddenAt: hidden,
      );

  group('the ticks on my own message', () {
    test('one tick while nobody has picked it up', () {
      expect(chat().statusOf(t1, 'them'), MessageStatus.sent);
    });

    test('two ticks once their device has it', () {
      final c = chat(delivered: {'them': t2});
      expect(c.statusOf(t1, 'them'), MessageStatus.delivered);
    });

    test('two green ticks once they have opened the chat', () {
      final c = chat(read: {'them': t2}, delivered: {'them': t2});
      expect(c.statusOf(t1, 'them'), MessageStatus.read);
    });

    test('a message sent after they last looked is not read', () {
      // They opened the chat at 11:00; this message went out at 12:00.
      final c = chat(read: {'them': t1}, delivered: {'them': t1});
      expect(c.statusOf(t2, 'them'), MessageStatus.sent);
    });

    test('reading it at the same instant still counts as read', () {
      // A boundary that decides between a green tick and a grey one, so it is
      // worth being explicit rather than leaving it to `isBefore`.
      final c = chat(read: {'them': t1});
      expect(c.statusOf(t1, 'them'), MessageStatus.read);
    });

    test('read wins over delivered, never the other way round', () {
      final c = chat(read: {'them': t2}, delivered: {'them': t0});
      expect(c.statusOf(t1, 'them'), MessageStatus.read);
    });
  });

  group('hiding a chat', () {
    test('a chat nobody hid stays in the list', () {
      expect(chat(lastMessageAt: t1).isHiddenFor('me'), isFalse);
    });

    test('hiding it takes it out of my list', () {
      final c = chat(lastMessageAt: t1, hidden: {'me': t2});
      expect(c.isHiddenFor('me'), isTrue);
    });

    test('and leaves it in theirs', () {
      // Removing your own clutter is not grounds for reaching into someone
      // else's history.
      final c = chat(lastMessageAt: t1, hidden: {'me': t2});
      expect(c.isHiddenFor('them'), isFalse);
    });

    test('a new message brings it back', () {
      // Hiding tidies a finished conversation; it does not block anyone.
      final c = chat(lastMessageAt: t2, hidden: {'me': t1});
      expect(c.isHiddenFor('me'), isFalse);
    });

    test('a chat with no messages at all stays hidden once hidden', () {
      final c = chat(lastMessageAt: null, hidden: {'me': t1});
      expect(c.isHiddenFor('me'), isTrue);
    });
  });

  group('reading a chat document', () {
    test('missing maps mean nobody has done anything yet', () {
      // Every chat created before this feature has none of the three fields.
      final c = ChatModel.fromFirestore(const {
        'participants': ['me', 'them'],
        'buyerId': 'me',
        'sellerId': 'them',
      }, 'c1');

      expect(c.deliveredAt, isEmpty);
      expect(c.hiddenAt, isEmpty);
      expect(c.lastRead, isEmpty);
      expect(c.isHiddenFor('me'), isFalse);
      expect(c.statusOf(t1, 'them'), MessageStatus.sent);
    });

    test('a junk value in the map does not take the whole list down', () {
      // One malformed document used to throw while parsing lastRead, which
      // fails the entire chat stream rather than one row.
      final c = ChatModel.fromFirestore(const {
        'participants': ['me', 'them'],
        'lastRead': {'them': 'not-a-timestamp'},
      }, 'c1');
      expect(c.lastRead, isEmpty);
    });
  });
}
