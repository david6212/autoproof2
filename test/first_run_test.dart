import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/core/constants/app_config.dart';

/// What a person meets in the first minute, before they have an account.
///
/// Written 25/08 while preparing to hand the app to friends. Looking at the
/// three screens a newcomer actually sees turned up three things that would
/// have made the app look broken to every one of them.
void main() {
  group('sign-in offers only what works', () {
    final login = File('lib/presentation/screens/auth/login_screen.dart')
        .readAsStringSync();

    test('Apple is behind a flag, and the flag is off', () {
      // The button was unconditional — on Android and in the browser, where it
      // is not even the platform convention. It needs the Apple provider in
      // Firebase, which needs a paid Apple Developer account that does not
      // exist yet, so every tap failed.
      expect(AppConfig.appleSignInEnabled, isFalse);
      expect(login, contains('if (AppConfig.appleSignInEnabled)'));
    });

    test('Google comes before the phone field', () {
      // Ordering IS the fix. Phone verification is broken, and the SMS field
      // was the first and loudest thing on the screen — so the first thing a
      // newcomer tried was the one thing that could not work.
      final google = login.indexOf("'המשך עם Google'");
      final phone = login.indexOf('_PhoneField(controller:');
      expect(google, greaterThan(-1));
      expect(phone, greaterThan(-1));
      expect(google, lessThan(phone));
    });

    test('the subtitle no longer promises an SMS as the way in', () {
      expect(login.contains("'נשלח אליך קוד אימות ב-SMS'"), isFalse);
      expect(login, contains('בלחיצה אחת עם חשבון Google'));
    });
  });

  test('a guest can withdraw consent and read the policy', () {
    // The guest is exactly the person who was asked about analytics on first
    // launch. While the profile tab was a pure login wall, somebody who tapped
    // "אפשר למדוד" had no way back — and GDPR Art. 7(3) requires withdrawal to
    // be as easy as consent was to give. Both stores also expect a route to
    // the privacy policy from inside the app.
    final profile = File('lib/presentation/screens/shared/profile_screen.dart')
        .readAsStringSync();
    final guestBranch = profile.substring(
      profile.indexOf('if (isGuest) {'),
      profile.indexOf('return Scaffold(', profile.indexOf('}\n\n    return')),
    );

    expect(guestBranch, contains('AnalyticsConsentTile()'));
    expect(guestBranch, contains("context.push('/legal')"));
  });

  test('the build number is on screen, for both a guest and an owner', () {
    // It lived only inside the support email's footer until 25/08. The first
    // thing anyone needs when a friend reports a problem is which build they
    // have — and with a side-loaded copy neither of them could see it.
    final profile = File('lib/presentation/screens/shared/profile_screen.dart')
        .readAsStringSync();

    expect('const _VersionLine(),'.allMatches(profile).length, 2,
        reason: 'once in the guest branch, once for a signed-in owner');
    expect(profile, contains('AppConfig.appVersion'));
  });

  test('an unknown address gets a Hebrew page, not a stack trace', () {
    // go_router's default draws "Page Not Found" in English over a raw
    // GoException. Every shared listing link carries a document id, so a stale
    // one is routine — and a foreign-language exception reads as "the app is
    // broken" rather than "that car is gone".
    final router = File('lib/app/router.dart').readAsStringSync();

    expect(router, contains('errorBuilder:'));
    expect(router, contains('הדף הזה לא קיים'));
    // It must not repeat the address back at someone who did not type it.
    expect(router.contains('state.error'), isFalse);
  });
}
