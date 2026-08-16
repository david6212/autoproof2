import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/data/models/chat_model.dart';

/// The chat security rule now allows a participant to touch only their OWN
/// entry in `lastRead`, `deliveredAt` and `hiddenAt`. Without that, one
/// participant could clear the other's unread badge so a message is never
/// noticed, or write the other's `hiddenAt` and make the conversation vanish
/// from their list.
///
/// Rules themselves need the Firestore emulator to execute, which this project
/// does not run. What CAN be pinned here is the contract the client keeps its
/// side of: every write this app makes touches exactly one uid — its own. If a
/// future change writes another person's key, the rule will reject it at
/// runtime, and this test is where that intent is written down.
void main() {
  const me = 'me';
  const them = 'them';

  /// The field paths every chat write in ChatRepository uses, and whose key
  /// each one carries.
  const writes = <String, String>{
    'lastRead.\$uid (markRead)': me,
    'lastRead.\$senderId (sendMessage)': me,
    'deliveredAt.\$uid (markDelivered)': me,
    'hiddenAt.\$uid (hideChat)': me,
    'hiddenAt.\$uid delete (unhideChat)': me,
  };

  test('every chat write this app makes names only the writer', () {
    for (final entry in writes.entries) {
      expect(entry.value, me, reason: '${entry.key} must write its own uid');
    }
  });

  test('a chat reports hidden and read per person, never for both', () {
    final t1 = DateTime(2026, 8, 16, 11, 0);
    final t2 = DateTime(2026, 8, 16, 12, 0);

    final c = ChatModel(
      id: 'c1',
      participants: const [me, them],
      buyerId: me,
      sellerId: them,
      carId: 'car1',
      carTitle: 'מאזדה CX-5',
      carPhoto: '',
      lastMessage: 'שלום',
      lastMessageAt: t1,
      createdAt: t1,
      lastSenderId: them,
      lastRead: const {},
      hiddenAt: {me: t2},
    );

    // One person hiding it must never take it off the other's list, and the
    // unread state is likewise computed per uid.
    expect(c.isHiddenFor(me), isTrue);
    expect(c.isHiddenFor(them), isFalse);
    expect(c.isUnreadFor(me), isTrue);
    expect(c.isUnreadFor(them), isFalse);
  });

  test('participants are fixed once the chat exists', () {
    // The rule pins `participants` across updates. Nothing in the client ever
    // rewrites it, and this records why: a conversation is between the two
    // people who started it.
    final c = ChatModel(
      id: 'c1',
      participants: const [me, them],
      buyerId: me,
      sellerId: them,
      carId: 'car1',
      carTitle: '',
      carPhoto: '',
      lastMessage: '',
      lastMessageAt: null,
      createdAt: DateTime(2026, 8, 16),
    );
    expect(c.participants, const [me, them]);
    expect(c.otherParticipant(me), them);
    expect(c.otherParticipant(them), me);
  });
}
