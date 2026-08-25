import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The headers the site sends, pinned as configuration.
///
/// Added 25/08 after a security review found the site sent nothing but HSTS:
/// any page in the world could put BonnetCheck in an invisible iframe and
/// collect a click on "פרסם" or "מחק חשבון" from someone who thought they were
/// clicking something else.
///
/// **The CSP allows `'unsafe-inline'` for scripts, and that is not an
/// oversight.** The FlutterFire loader injects `<script>` elements to pull in
/// the Firebase modules. Without it, Chrome refused five of them, only
/// `firebase-app.js` loaded, and the marketplace rendered an empty page while
/// still reporting itself as "loaded" — measured on the deployed site before
/// this was relaxed. Static hosting has nowhere to mint a nonce.
///
/// What the policy still buys with that concession: nothing may frame the
/// site, no plugins, no base-tag hijack, forms may only post to us, and the
/// allow-lists cap where a script could send data or pull an image from.
void main() {
  final config = jsonDecode(File('firebase.json').readAsStringSync());
  final hosting = (config['hosting'] as List).first as Map<String, dynamic>;
  final block = (hosting['headers'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((h) => h['source'] == '**');
  final headers = {
    for (final h in (block['headers'] as List).cast<Map<String, dynamic>>())
      h['key'] as String: h['value'] as String,
  };
  final csp = headers['Content-Security-Policy']!;

  test('the site cannot be framed — two ways, for old browsers too', () {
    expect(csp, contains("frame-ancestors 'none'"));
    expect(headers['X-Frame-Options'], 'DENY');
  });

  test('the basics are all present', () {
    expect(headers['X-Content-Type-Options'], 'nosniff');
    expect(headers['Referrer-Policy'], 'strict-origin-when-cross-origin');
    expect(headers, contains('Permissions-Policy'));
  });

  test('only the two map screens may ask for location', () {
    // Camera, microphone and payment are refused outright rather than left
    // to default, so an embedded frame cannot inherit them either.
    final policy = headers['Permissions-Policy']!;
    expect(policy, contains('geolocation=(self)'));
    for (final off in ['camera=()', 'microphone=()', 'payment=()']) {
      expect(policy, contains(off));
    }
  });

  test('fonts may come from nowhere but us', () {
    // The reason this line is here: Flutter's web engine answers a missing
    // glyph by downloading a Noto fallback from fonts.gstatic.com at runtime.
    // A single "←" on the login screen was doing exactly that, months after
    // the fonts were bundled to stop it. The character is gone, and this
    // directive is what makes the next one fail loudly instead of quietly.
    expect(csp, contains("font-src 'self';"));
    expect(csp.contains('fonts.gstatic.com'), isFalse);
    expect(csp.contains('fonts.googleapis.com'), isFalse);
  });

  test('the allow-lists name every host the app really uses', () {
    // Measured from the deployed app, not guessed: the registry proxy, the map
    // tiles, Firestore and auth. A host missing here is a feature that dies
    // silently in the browser.
    for (final host in [
      'https://firestore.googleapis.com',
      'https://identitytoolkit.googleapis.com',
      'https://securetoken.googleapis.com',
      'https://tile.openstreetmap.org',
      'https://sweet-breeze-97b0.davidmalede.workers.dev',
    ]) {
      expect(csp, contains(host), reason: host);
    }
  });

  test('plugins, base tags and off-site form posts are refused', () {
    expect(csp, contains("object-src 'none'"));
    expect(csp, contains("base-uri 'self'"));
    expect(csp, contains("form-action 'self'"));
  });

  test('the landing page keeps no inline script for the CSP to refuse', () {
    // The hash-redirect that sends an old shared link to /app/ lives in its
    // own file now. Inline, it would be refused, and every link shared before
    // the move would land on the wrong page — silently.
    final html = File('landing/index.html').readAsStringSync();
    expect(html, contains('<script src="/hash-redirect.js"></script>'));
    expect(File('landing/hash-redirect.js').existsSync(), isTrue);
  });
}
