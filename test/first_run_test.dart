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

  group('the measurement question waits its turn', () {
    // Measured on the live site 26/08, on a browser profile with nothing
    // stored: the consent sheet was painted over slide one of the onboarding.
    // The very first thing a stranger met was a paragraph about persistent
    // identifiers and Firebase Analytics — before a single word about what
    // BonnetCheck is or does.
    final gate =
        File('lib/presentation/widgets/analytics_consent_gate.dart')
            .readAsStringSync();
    final provider =
        File('lib/presentation/providers/analytics_consent_provider.dart')
            .readAsStringSync();

    test('the opening screens are named, and asked about', () {
      expect(gate, contains('_introRoutes'));
      for (final route in ['/splash', '/onboarding']) {
        expect(gate, contains("'$route'"),
            reason: '$route is an opening screen and must not be asked over');
      }
      expect(gate, contains('_onIntroScreen'));
    });

    test('an unsettled router counts as still opening', () {
      // The safe direction to fail in. If the location cannot be read, asking
      // later costs nothing; asking now risks landing on the first screen
      // again, which is the whole bug.
      expect(gate, contains('return loc == null || _introRoutes.contains(loc)'));
    });

    test('the location is re-read after the settle delay, not only before', () {
      // Two seconds is long enough to navigate. Checking only on the way in
      // would let the sheet open onto a screen that arrived during the wait.
      final settle = gate.indexOf('Duration(seconds: 2)');
      final recheck = gate.indexOf('if (_onIntroScreen) {');
      expect(settle, greaterThan(-1));
      expect(recheck, greaterThan(settle),
          reason: 'the re-check has to come after the delay it guards');
    });

    test('a blocked attempt is given back, not spent', () {
      // Attempts are capped at 5. Burning them while the reader is still in
      // the onboarding would mean nobody is ever asked at all.
      expect(gate, contains('_attempts--'));
    });

    test('waiting is free: nothing is measured before the answer', () {
      // This is what makes the delay lawful rather than merely nicer. If
      // collection ran while unasked, the sheet would have to come first and
      // the ordering above would be a compliance regression, not a fix.
      expect(provider,
          contains('if (kIsWeb && !granted && !_touched) return;'));
      expect(provider, contains('AnalyticsConsent.unasked'));
      // "Still loading" and "failed" both have to count as no.
      expect(provider, contains('AnalyticsConsent.granted;'));
    });
  });
}
