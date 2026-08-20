import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/core/constants/legal_docs.dart';
import 'package:bonnetcheck/core/constants/legal_info.dart';

/// The published policy has to be the policy the app shows.
///
/// The documents live in Dart and are rendered to static HTML by
/// `tool/gen_legal.dart`, which `tool/build_site.sh` runs on every build. Two
/// things can go wrong with that arrangement, and both are silent: a new
/// document is added and never rendered, or a paragraph is edited in Dart
/// while the published page keeps the old wording. The second is the one that
/// matters — a privacy policy that disagrees with itself in public is worse
/// than one that is merely out of date.
void main() {
  String page(String id) =>
      File('landing/legal/$id/index.html').readAsStringSync();

  test('every document in the app has a page on the site', () {
    for (final doc in LegalDocs.all) {
      expect(
        File('landing/legal/${doc.id}/index.html').existsSync(),
        isTrue,
        reason: 'run: dart run tool/gen_legal.dart',
      );
    }
    expect(File('landing/legal/index.html').existsSync(), isTrue);
  });

  test('the published text still matches the app, heading for heading', () {
    for (final doc in LegalDocs.all) {
      final html = page(doc.id);
      expect(html, contains(doc.title));
      for (final section in doc.sections) {
        expect(
          html,
          contains(section.heading),
          reason: '${doc.id} is stale — regenerate it',
        );
      }
    }
  });

  test('a page names the operator and a live address', () {
    // The generator refuses to write anything while either is blank; this is
    // the other half of that rule, checked from the outside.
    expect(LegalInfo.isPublished, isTrue);
    expect(page(LegalDocs.privacy), contains(LegalInfo.contactEmail));
  });

  test('a policy page carries no request to another server', () {
    // Self-contained on purpose: a policy that needs a font host to render is
    // a policy that sometimes does not render, and one that quietly reports
    // its readers to a third party while explaining that it does not.
    for (final doc in LegalDocs.all) {
      final html = page(doc.id);
      expect(html.contains('http://'), isFalse);
      for (final host in const ['fonts.googleapis', 'gstatic', 'analytics']) {
        expect(html.contains(host), isFalse, reason: '${doc.id} calls out');
      }
    }
  });

  group('the landing page', () {
    final landing = File('landing/index.html').readAsStringSync();

    test('links to the documents directly, not through the app', () {
      // `/app/#/legal/privacy` meant downloading the whole Flutter bundle to
      // read a page of text — and a store reviewer or a crawler will not.
      expect(landing.contains('/app/#/legal/'), isFalse);
      for (final id in const ['terms', 'privacy', 'cookies', 'removal']) {
        expect(landing, contains('href="/legal/$id"'));
      }
    });

    test('carries this app\'s name and not the previous one', () {
      // The wordmark is drawn in markup rather than read from a string, so the
      // July rename missed it and the site's front door read "Oto" for a
      // month.
      expect(landing.contains('>Oto<'), isFalse);
      expect(landing, contains('>Bonnet<'));
    });
  });
}
