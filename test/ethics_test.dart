import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The rules from §6 of the UX spec, enforced against the whole source tree.
///
/// This one is not really about today's code — today's code is clean. It is
/// about the next person to work here, human or agent, who will one day be
/// asked to "improve engagement" and will reach for the patterns every other
/// marketplace uses. Those patterns are cheap, they work, and adopting a
/// single one of them would cost this app the only thing it sells: that it
/// does not push.
///
/// Hebrew appears in this codebase only inside string literals — every
/// comment is written in English — so scanning raw file text is enough to
/// find user-facing copy without parsing Dart.
void main() {
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  /// Reports every file containing [needle], with its line number.
  List<String> hits(String needle) {
    final found = <String>[];
    for (final file in dartFiles) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains(needle)) found.add('${file.path}:${i + 1}');
      }
    }
    return found;
  }

  void banned(String needle, String why) {
    expect(hits(needle), isEmpty, reason: '"$needle" — $why');
  }

  group('§6.1 — no manufactured urgency', () {
    test('nothing counts down, crowds, or runs out', () {
      // Phrases, not words. "נותרו" on its own is honest arithmetic — the
      // documented-history meter says "נותרו רשומה אחת וחודש אחד", which is a
      // fact about the owner's own records. It is scarcity framing that is
      // banned, so the patterns below all pair a count with pressure.
      banned('נותרו רק', 'invented scarcity');
      banned('נשארו רק', 'invented scarcity');
      banned('צופים עכשיו', 'fake concurrent viewers');
      banned('צופים ברכב', 'fake concurrent viewers');
      banned('הזדמנות אחרונה', 'manufactured deadline');
      banned('לזמן מוגבל', 'manufactured deadline');
      banned('מיהרו', 'pressure');
      banned('אל תפספסו', 'pressure');
      banned('המחיר עולה', 'a threat we cannot honour — we do not set prices');
    });
  });

  group('§6.2 — the app does not advise on price', () {
    test('days on market is never dressed as a recommendation', () {
      // The number itself is fine and useful. "Consider lowering" makes
      // BonnetCheck a party to the negotiation, which it is not.
      banned('שקול להוריד', 'price advice');
      banned('שקלו להוריד', 'price advice');
      banned('מומלץ להוריד את המחיר', 'price advice');
    });
  });

  group('§6.4 — no gamification beyond the one earned badge', () {
    test('no streaks, points or levels', () {
      // "תיק מתועד" is allowed because it states a checkable fact about
      // records. Everything here rewards using the app instead.
      banned('הרצף שלך', 'streaks reward habit, not substance');
      banned('נקודות שצברת', 'points');
      banned('טבלת המובילים', 'leaderboards');
      banned('השלמת הפרופיל', 'completion meters on the person');
    });
  });

  group('§6.5 — leaving is as easy as arriving', () {
    test('no confirmshaming', () {
      // A decline button that insults the person choosing it.
      banned('אני מוותר על', 'confirmshaming');
      banned('לא תודה, אני', 'confirmshaming');
      banned('אני לא רוצה לחסוך', 'confirmshaming');
    });
  });

  group('§6.5 — leaving is as easy as arriving, in the code', () {
    test('unsaving a listing asks nobody anything', () {
      // One tap out, the same as one tap in. A confirmation here would be
      // friction added to the direction we would rather people did not go,
      // which is the whole pattern §6.5 exists to forbid.
      final saved = File('lib/presentation/screens/buyer/saved_screen.dart');
      expect(saved.readAsStringSync().contains('showDialog'), isFalse,
          reason: 'a dialog on the way out of a saved list is a dark pattern');
    });

    test('deleting the account happens in the app, in one tap', () {
      // It used to file a *request* into a collection no client can read —
      // which is an automatic App Store rejection (§5.1.1(v)) and, worse, a
      // promise the product could not keep. The entanglement argument behind
      // that was real but misapplied: what belongs to the person goes with
      // them; what they wrote about other people's cars is other buyers'
      // evidence and stays.
      final profile =
          File('lib/presentation/screens/shared/profile_screen.dart')
              .readAsStringSync();
      expect(profile.contains('מחיקת החשבון והמידע שלי'), isTrue);
      expect(profile.contains('_requestDeletion'), isTrue);
      expect(profile.contains('deleteEverything()'), isTrue,
          reason: 'the button must delete, not file a ticket');
    });
  });

  group('§6.6 — absence of a finding is never shown as approval', () {
    test('the app never certifies a car', () {
      // The load-bearing rule. Everything else in this file protects the
      // product; this one protects the claim the product is built on, and it
      // is the only rule here with a legal edge.
      banned('רכב תקין', 'a verdict on the vehicle');
      banned('הרכב תקין', 'a verdict on the vehicle');
      banned('לא נמצאו בעיות', 'reads as a clean bill of health');
      banned('לא נמצאו ליקויים', 'reads as a clean bill of health');
      banned('הרכב נבדק ואושר', 'we approve nothing');
      banned('מאושר על ידינו', 'we approve nothing');
      banned('רכב מאומת', 'we verify records, never vehicles');
    });
  });
}
