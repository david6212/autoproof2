import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/router.dart';

/// A vehicle passport is private by security rule, not by convention. Before
/// this guard existed, a signed-out visitor following a link to one did not
/// get a login prompt — they got a Firestore permission error rendered as
/// "we couldn't load this", above a retry button that could never succeed.
///
/// The interesting half is what is deliberately NOT gated: the marketplace is
/// browsable without an account, and that is the whole first impression.
void main() {
  group('routes that need an account', () {
    test('every passport action is gated', () {
      expect(needsAccount('/garage/add'), isTrue);
      expect(needsAccount('/garage/claim'), isTrue);
      expect(needsAccount('/vehicle/abc123'), isTrue);
      expect(needsAccount('/vehicle/abc123/publish'), isTrue);
      expect(needsAccount('/vehicle/abc123/sell'), isTrue);
      expect(needsAccount('/profile/past-vehicles'), isTrue);
    });
  });

  group('routes that stay open to a guest', () {
    test('the garage tab itself invites rather than bounces', () {
      // A bottom tab that throws you to a login screen is hostile. That screen
      // explains what a passport is; the actions underneath it need the
      // account.
      expect(needsAccount('/garage'), isFalse);
    });

    test('the whole marketplace stays browsable without signing in', () {
      // This is the first impression, and the reason anyone signs up at all.
      for (final open in [
        '/home',
        '/car/abc123',
        '/car/abc123/history',
        '/saved',
        '/fuel',
        '/compare',
        '/inspectors/abc123',
        '/profile',
        '/about',
        '/legal',
      ]) {
        expect(needsAccount(open), isFalse, reason: '$open must stay open');
      }
    });

    test('a car listing is not mistaken for a vehicle passport', () {
      // `/car/` and `/vehicle/` differ by four letters and mean opposite
      // things: one is public and the point of the app, the other is private.
      expect(needsAccount('/car/abc123'), isFalse);
      expect(needsAccount('/vehicle/abc123'), isTrue);
    });
  });
}
