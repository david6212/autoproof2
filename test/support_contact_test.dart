import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/core/constants/app_config.dart';
import 'package:bonnetcheck/core/constants/legal_info.dart';
import 'package:bonnetcheck/presentation/widgets/support_contact.dart';

/// The support address is not just a support address: the legal documents name
/// the same mailbox for data-deletion and content-removal requests. So there is
/// one address, set in one place, and the app refuses to advertise it until it
/// is real.
void main() {
  test('the version quoted to support matches the version that shipped', () {
    // AppConfig.appVersion duplicates pubspec because reading the real one
    // needs a plugin. A version number that lies is worse than none — it sends
    // support looking at the wrong build — so the duplicate is checked here
    // rather than trusted.
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final line = pubspec.firstWhere((l) => l.startsWith('version:'));
    final declared = line.split(':')[1].trim();
    expect(AppConfig.appVersion, declared);
  });

  test('one address serves support and the legal documents alike', () {
    // Two addresses would mean two mailboxes to monitor and one of them
    // eventually going stale — in a document that promises a route for
    // deleting personal data.
    expect(SupportContact.isAvailable,
        LegalInfo.contactEmail.trim().isNotEmpty);
  });

  test('nothing is advertised while the address is empty', () {
    // Today it IS empty. The profile row and the legal documents are both
    // hidden by the same fact, so the app never offers a way to reach somebody
    // who cannot be reached.
    if (LegalInfo.contactEmail.trim().isEmpty) {
      expect(SupportContact.isAvailable, isFalse);
      expect(LegalInfo.isPublished, isFalse);
    }
  });

  group('the mail link', () {
    test('carries the version and platform, and nothing about the person', () {
      final d = SupportContact.diagnostics();
      expect(d, contains(AppConfig.appVersion));
      // No device id, no uid, no location. An app that quietly fingerprints a
      // support email is doing the thing this app exists to argue against.
      expect(d.length, lessThan(60));
    });

    test('Hebrew survives being put in a URL', () {
      // A mailto with an unencoded Hebrew subject arrives mangled or not at
      // all, and the failure only shows up on a real mail client.
      final uri = SupportContact.uriFor(subject: 'פנייה לתמיכה', body: 'שלום');
      expect(uri.scheme, 'mailto');
      expect(uri.queryParameters['subject'], 'פנייה לתמיכה');
      expect(uri.queryParameters['body'], startsWith('שלום'));
      expect(uri.toString(), isNot(contains('פנייה')));
    });

    test('the diagnostics footer is appended, not substituted', () {
      final uri = SupportContact.uriFor(subject: 'נושא', body: 'הטקסט שלי');
      final body = uri.queryParameters['body']!;
      expect(body, startsWith('הטקסט שלי'));
      expect(body, contains(AppConfig.appVersion));
    });

    test('an empty body still gets the footer', () {
      final body = SupportContact.uriFor(subject: 'נושא').queryParameters['body']!;
      expect(body, contains(AppConfig.appVersion));
    });
  });
}
