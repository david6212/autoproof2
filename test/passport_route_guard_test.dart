import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/router.dart';
import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/presentation/providers/auth_provider.dart';

/// The only way to get a [Ref] to hand to [AuthRefresh] outside the app.
final _refreshProvider = Provider<AuthRefresh>((ref) => AuthRefresh(ref));

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

    test('a shared chat link too', () {
      // The one route that genuinely dead-ends. ChatScreen has no guest
      // branch — it reads the uid as '' and streams the thread anyway, and
      // `chats` requires isSignedIn(), so a visitor following a link gets a
      // Firestore permission error dressed as "we couldn't load this", under
      // a retry button that can never succeed. That is precisely the failure
      // this guard exists to prevent.
      expect(needsAccount('/chat/abc123'), isTrue);
      expect(needsAccount('/chats'), isFalse,
          reason: 'the list is a tab, and it shows a guest prompt');
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

    test('a screen that asks for an account itself is not bounced', () {
      // These three need an account for their *content*, and a security scan
      // read that as four missing entries in the gated list. They are not.
      // Each already answers a guest in place, and the invitation it shows is
      // better than a redirect: SavedScreen and NotificationsScreen render a
      // GuestPromptView that says what signing in would get you, and the
      // whole seller flow is open to guests on purpose —
      // `create_listing_provider.dart` says so where it refuses to publish:
      // "A guest may walk the whole flow — that is the point of it". The
      // account is asked for at the end, when the reason for it is visible.
      //
      // Gating them would undo that. `/seller` in particular would put back
      // the bounce that three screens were deleted to remove.
      expect(needsAccount('/saved'), isFalse);
      expect(needsAccount('/notifications'), isFalse);
      expect(needsAccount('/seller'), isFalse);
      expect(needsAccount('/seller/create'), isFalse);
    });

    test('a car listing is not mistaken for a vehicle passport', () {
      // `/car/` and `/vehicle/` differ by four letters and mean opposite
      // things: one is public and the point of the app, the other is private.
      expect(needsAccount('/car/abc123'), isFalse);
      expect(needsAccount('/vehicle/abc123'), isTrue);
    });
  });

  /// The half that runs in front of users, and that nothing above touches.
  ///
  /// Every test up to here checks [needsAccount], a pure string predicate that
  /// was never the thing that broke. The guard failed in production while all
  /// of them passed, because a cold start reaches [accountRedirect] while auth
  /// is still loading — and nothing asked a second time.
  group('the decision the router actually makes', () {
    const loading = AsyncValue<User?>.loading();
    const signedOut = AsyncValue<User?>.data(null);

    test('a signed-out visitor on a passport link is sent to log in', () {
      expect(accountRedirect('/vehicle/abc123', signedOut), '/login');
      expect(accountRedirect('/garage/add', signedOut), '/login');
      expect(accountRedirect('/garage/claim', signedOut), '/login');
      expect(accountRedirect('/profile/past-vehicles', signedOut), '/login');
    });

    test('an open route is never bounced, signed out or not', () {
      for (final open in ['/home', '/garage', '/car/abc123', '/fuel']) {
        expect(accountRedirect(open, signedOut), isNull, reason: open);
        expect(accountRedirect(open, loading), isNull, reason: open);
      }
    });

    test('nobody is bounced while the answer is still unknown', () {
      // The reason the guard waits at all: bouncing here would throw a
      // signed-in user to the login screen during the first frames of every
      // cold start.
      expect(accountRedirect('/vehicle/abc123', loading), isNull);
    });

    test('loading then signed-out resolves to the login screen', () {
      // The exact cold-start sequence that used to dead-end. The first answer
      // is "wait"; the second has to be "/login", and something has to ask.
      expect(accountRedirect('/vehicle/abc123', loading), isNull);
      expect(accountRedirect('/vehicle/abc123', signedOut), '/login');
    });
  });

  group('asking a second time', () {
    test('a change in auth notifies the router', () async {
      // AuthRefresh is the whole fix. Without a listener go_router evaluates
      // redirect once per navigation, so the "wait" above would be the last
      // word and the visitor would sit on a screen that cannot load.
      final controller = StreamController<User?>();
      addTearDown(controller.close);

      final container = ProviderContainer(overrides: [
        authStateProvider.overrideWith((ref) => controller.stream),
      ]);
      addTearDown(container.dispose);

      final refresh = container.read(_refreshProvider);

      var notified = 0;
      refresh.addListener(() => notified++);

      controller.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(notified, greaterThan(0),
          reason: 'the router has to be told the answer arrived');
    });
  });

  group('and the real router does it', () {
    testWidgets('a cold link to a chat lands on the login screen',
        (tester) async {
      // Everything above tests functions. This tests the app: the actual
      // `routerProvider`, its actual redirect, its actual AuthRefresh, driven
      // the way a shared link drives it — a cold start where the auth answer
      // is still loading when the location arrives.
      //
      // The guard's whole history is of being present in source and absent in
      // production, so a list that contains '/chat/' proves nothing on its
      // own. This is the part that could not be faked.
      final container = ProviderContainer(overrides: [
        authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
      ]);
      addTearDown(container.dispose);

      final router = container.read(routerProvider);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ));

      router.go('/chat/abc123');
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(router.routerDelegate.currentConfiguration.uri.path, '/login',
          reason: 'the visitor was left on a chat that can never load');
    });
  });
}
