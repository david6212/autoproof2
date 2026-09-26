import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/data/models/service_record.dart';

/// The second pass of the 24/09 scan: the receipt, and the fields a buyer
/// trusts on a listing.
///
/// Both are the same shape of mistake. A document that says something a buyer
/// relies on was writable by the person it describes, and a file that a
/// document promised was private was reachable by anybody who could read the
/// document.
void main() {
  final rules = File('firestore.rules').readAsStringSync();

  String slice(String from, String to) {
    final a = rules.indexOf(from);
    if (a < 0) throw StateError('firestore.rules has no $from');
    final b = rules.indexOf(to, a + from.length);
    return b < 0 ? rules.substring(a) : rules.substring(a, b);
  }

  group('SEC-03 — the invoice is not published with the history', () {
    test('the record is still readable to a buyer', () {
      // The point of a passport. Removing this would fix the leak by deleting
      // the feature.
      final services = slice('match /services/{serviceId} {', 'allow create');
      expect(services, contains('isListed == true'));
    });

    test('the file under it is owner-only, with no listed branch', () {
      final file = slice('match /services/{serviceId}/file/{blobId} {', '}');
      expect(file, contains('ownerId == request.auth.uid'));
      expect(file.contains('isListed'), isFalse,
          reason: 'a listed car must not publish the invoice behind the record');
    });

    test('nothing writes a download URL into a public document any more', () {
      // Comment-stripped: both files explain in a comment what was removed and
      // why, and a check that could not tell an explanation from a call site
      // would force the explanation out — which is how the reason gets lost.
      String code(String src) => src
          .split(RegExp('[\r\n]+'))
          .where((l) => !l.trimLeft().startsWith('//'))
          .join(' ');

      final model = File('lib/data/models/service_record.dart').readAsStringSync();
      expect(code(model).contains('receiptUrl'), isFalse);
      expect(model, contains('hasReceipt'));

      final storage =
          File('lib/data/repositories/storage_repository.dart').readAsStringSync();
      expect(code(storage).contains('uploadServiceReceipt'), isFalse,
          reason: 'the Storage path is gone, not merely unused');
      expect(storage, contains('was removed on 26/09'),
          reason: 'and the reason stays where the next reader will look');
    });

    test('a record carries a flag, never a link', () {
      final record = ServiceRecord(
        id: 's1',
        type: ServiceType.repair,
        title: 'החלפת רפידות',
        date: DateTime(2026, 4, 1),
        km: 90000,
        hasReceipt: true,
        addedByOwnerId: 'u1',
        createdAt: DateTime(2026, 4, 1),
      ).toFirestore();

      expect(record['hasReceipt'], isTrue);
      expect(record.keys.any((k) => k.toLowerCase().contains('url')), isFalse);
    });

    test('the buyer-facing timeline has no way to open one', () {
      // The security half is the rule; this is the half that stops a
      // permission error being offered to a buyer as a button.
      final timeline =
          File('lib/presentation/widgets/service_timeline.dart').readAsStringSync();
      expect(timeline, contains('record.hasReceipt && onOpenReceipt != null'));

      final buyerCard = File('lib/presentation/widgets/documented_history_card.dart')
          .readAsStringSync();
      expect(buyerCard.contains('onOpenReceipt'), isFalse,
          reason: "the buyer's copy must not pass the callback");
    });
  });

  group('SEC-06 — a listing cannot claim what its passport does not hold', () {
    final cars = slice('match /cars/{carId} {', 'match /private/{docId}');

    test('the documentation claim is checked against the vehicle', () {
      expect(rules, contains('function claimsMatchThePassport'));
      expect(rules, contains('function documentedByRecord'));
      expect(cars, contains('claimsMatchThePassport(request.resource.data)'));
    });

    test('and the same threshold the app uses — three records, six months', () {
      final fn = slice('function documentedByRecord', '}');
      expect(fn, contains("serviceCount', 0) >= 3"));
      // 180 days in milliseconds; the app counts months as days ~/ 30.
      expect(fn, contains('15552000000'));
    });

    test('a listing with no passport may not claim one', () {
      final fn = slice('function claimsMatchThePassport', 'function claimsUnchanged');
      expect(fn, contains("!('vehicleId' in d)"));
      expect(fn, contains("hasDocumentedHistory', false) == false"));
    });

    test('a listing cannot be handed to another account', () {
      expect(cars, contains(
          'request.resource.data.sellerId == resource.data.sellerId'));
    });

    test('nor its age reset — retention counts from it', () {
      expect(cars, contains(
          'request.resource.data.createdAt == resource.data.createdAt'));
    });

    test("the registry's answer is frozen after publication", () {
      expect(cars, contains("get('govSnapshot', {})"));
    });

    test('what is still open is written down, not implied', () {
      // A rule cannot call data.gov.il, so a forged snapshot at create time
      // survives this fix. The comment says so where the next reader will be.
      expect(rules, contains('a rule cannot call'));
    });
  });

  group('SEC-12 — a message has a ceiling', () {
    final messages = slice('match /messages/{messageId} {', '}');

    test('two thousand characters, checked in the rules', () {
      expect(messages, contains("get('text', '').size() <= 2000"));
    });

    test('and the conversation stays append-only', () {
      expect(messages.contains('allow update'), isFalse);
      expect(messages.contains('allow delete'), isFalse);
    });
  });

  test('SEC-16 — the release is signed v2 + v3, and not v1', () {
    // Raising minSdk to 24 was supposed to turn v3 on by itself. It did not:
    // the published 0.9.13 came back `v3 scheme: false` from
    // `apksigner verify --verbose`, so the schemes are named explicitly. The
    // lesson is the general one — verify the artefact, not the documentation.
    //
    // v1 is JAR signing, what CVE-2017-13156 attacks, and it matters for a
    // sideloaded APK; nothing below Android 7 can install this build anyway.
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('minSdk = 24'));
    expect(gradle, contains('enableV3Signing = true'));
    expect(gradle, contains('enableV2Signing = true'));
    expect(gradle, contains('enableV1Signing = false'));
  });
}
