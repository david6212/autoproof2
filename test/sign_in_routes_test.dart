import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/core/constants/app_config.dart';

/// A button that always fails is worse than a button that is not there.
///
/// The app writes that rule down in `app_config.dart` and had already applied
/// it twice — to Apple sign-in, which has no provider behind it, and to file
/// uploads, which need Storage. Phone sign-in was the third failing route and
/// the only one still on screen: Firebase phone auth needs the Blaze plan, and
/// on Spark every send comes back `BILLING_NOT_ENABLED`.
///
/// Ordering the field below Google was a real improvement and not the fix.
/// Store reviewers test authentication, and a reviewer who types a number and
/// gets an error has found a broken app however politely the error is worded.
void main() {
  final login = File('lib/presentation/screens/auth/login_screen.dart')
      .readAsStringSync();

  group('the sign-in screen offers only routes that can work', () {
    test('phone sign-in is off while it cannot succeed', () {
      expect(AppConfig.phoneAuthEnabled, isFalse,
          reason: 'turn this on with Blaze, not before');
    });

    test('the phone field is behind the flag, not merely demoted', () {
      // Both halves: the input and the button that submits it. Gating one and
      // leaving the other is how a screen ends up with a send button and
      // nothing to send.
      expect(login, contains('AppConfig.phoneAuthEnabled && !isCodeStep'));
      expect(login, contains('else if (AppConfig.phoneAuthEnabled)'));
    });

    test('the divider goes with it', () {
      // "או" under a single button reads as something that failed to load.
      final divider = login.indexOf('_OrDivider()');
      expect(divider, greaterThan(-1));
      final before = login.substring(0, divider);
      expect(before.lastIndexOf('AppConfig.phoneAuthEnabled'),
          greaterThan(before.lastIndexOf('_SocialButton')),
          reason: 'the divider must be inside the flag, not above it');
    });

    test('the subtitle does not promise the route that is hidden', () {
      // The line under the title used to offer "או במספר טלפון" whatever was
      // actually on the screen below it.
      expect(login, contains("'בלחיצה אחת, עם חשבון Google.'"));
    });

    test('Google is never gated — it is the route that works', () {
      final google = login.indexOf("'המשיכו עם Google'");
      expect(google, greaterThan(-1));
      expect(login.substring(0, google).contains('if (AppConfig.phoneAuth'),
          isFalse);
    });
  });

  group('the government proxy is not an open relay', () {
    final worker = File('tool/gov_cors_proxy.js').readAsStringSync();

    test('a request that is neither a known origin nor the app is refused', () {
      // It used to pass anything with no Origin header, on the reasoning that
      // whatever can omit a header can forge one. True, and beside the point:
      // Cloudflare's terms ask whether we operate a proxy for third parties,
      // and with that door open we did.
      expect(worker, contains('CLIENT_HEADER'));
      expect(worker, contains("origin ? !allowed(origin) : !named"));
    });

    test('the phone can still reach its own fallback', () {
      // The trap in the obvious fix. The phone calls data.gov.il directly and
      // only comes here when that fails — and it sends no Origin at all,
      // because Dart's HTTP client is not subject to CORS. Requiring an Origin
      // would have deleted the fallback rather than tightened it.
      final service = File('lib/data/sources/remote/gov_api_service.dart')
          .readAsStringSync();
      expect(service, contains("'X-BonnetCheck-Client'"));
      expect(worker, contains("'X-BonnetCheck-Client'"));
    });

    test('the header is not sent from a browser', () {
      // There it would buy nothing — the Origin already names us — and cost a
      // CORS preflight on every single lookup.
      final service = File('lib/data/sources/remote/gov_api_service.dart')
          .readAsStringSync();
      expect(service, contains('kIsWeb'));
    });
  });
}
