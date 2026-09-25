import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/core/constants/app_config.dart';
import 'package:bonnetcheck/core/theme/app_palette.dart';
import 'package:bonnetcheck/data/models/escort_pro.dart';
import 'package:bonnetcheck/data/repositories/operator_inbox_repository.dart';
import 'package:bonnetcheck/presentation/widgets/escort_invite_card.dart';
import 'package:bonnetcheck/presentation/widgets/escort_verification_chip.dart';

/// "ליווי מקצועי לבדיקה" — people who will come with a buyer to look at a car.
///
/// Built 25/09 and **shipped off**: the open question is not technical. Paid
/// accompaniment may make this app a broker or an inspection institute under
/// the vehicle-trade licensing law, and the operator's exposure to a
/// professional's opinion is unsettled. Both are questions 10 and 11 in the
/// lawyer brief. So these tests hold two things: that nothing reaches a user
/// while the flag is off, and that when it is on, no one can award themselves
/// a badge.
void main() {
  final rules = File('firestore.rules').readAsStringSync();

  // Plain `throw` rather than `expect`: this runs while the groups are being
  // declared, and an expectation outside a test throws an unhelpful
  // OutsideTestException instead of naming the rule that went missing.
  String block(String header) {
    final start = rules.indexOf(header);
    if (start < 0) throw StateError('firestore.rules has no $header');
    final after = rules.indexOf('    match /', start + 12);
    return after == -1 ? rules.substring(start) : rules.substring(start, after);
  }

  group('the feature is off, and off means absent', () {
    test('the flag is false', () {
      expect(AppConfig.escortEnabled, isFalse,
          reason: 'turning this on is a legal decision, not a code change');
    });

    test('the routes are not registered at all', () {
      // Not a redirect: a link shared while the feature was on must not reach
      // a screen after it was turned off.
      final router = File('lib/app/router.dart').readAsStringSync();
      expect(router, contains('if (AppConfig.escortEnabled) ...['));
    });

    testWidgets('the invitation on a listing draws nothing', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: const [AppPalette.light]),
        home: const Scaffold(body: EscortInviteCard()),
      ));

      expect(find.byType(Card), findsNothing);
      expect(tester.getSize(find.byType(EscortInviteCard)).height, 0,
          reason: 'must leave no gap on the listing it sits in');
    });

    test('and the provider does not even read the collection', () {
      final provider = File('lib/presentation/providers/escort_provider.dart')
          .readAsStringSync();
      expect(provider, contains('if (!AppConfig.escortEnabled)'));
    });
  });

  group('nobody can award themselves a badge', () {
    // The heart of it. There is no server on Spark, so a rule cannot ask the
    // Ministry whether a licence number is real. The applicant's claim and the
    // checked fact are therefore different fields, with different writers.
    final pros = block('match /escort_pros/{proId} {');

    test('the applicant writes a claim, not a licence', () {
      expect(pros, contains('claimedLicence'));
      final ownerUpdate = pros.substring(
        pros.indexOf('allow update: if isSignedIn()'),
        pros.indexOf('allow update: if isOperator()'),
      );
      for (final field in [
        'garageLicence',
        'garageName',
        'garageTown',
        'certCheckedAt',
        'isHidden',
        'ratingCount',
      ]) {
        expect(ownerUpdate.contains("'$field'"), isFalse,
            reason: '$field must not be writable by the profile owner');
      }
    });

    test('an owner cannot approve their own certificate', () {
      expect(pros, contains("request.resource.data.certStatus in ['none', 'pending']"));
      expect(pros, contains("resource.data.certStatus != 'approved'"));
    });

    test('the verified fields have exactly one writer', () {
      final operatorUpdate = pros.substring(pros.indexOf('allow update: if isOperator()'));
      expect(operatorUpdate, contains("'garageLicence'"));
      expect(operatorUpdate, contains("'certStatus'"));
      expect(operatorUpdate, contains("'isHidden'"));
    });

    test('a profile is never deleted, only hidden', () {
      expect(pros, contains('allow delete: if false'));
    });

    test('the application lands in the fourteen-day inbox', () {
      expect(InboxKind.values, contains(InboxKind.proApplication));
      expect(InboxKind.proApplication.collection, 'pro_applications');
      final apps = block('match /pro_applications/{applicationId} {');
      expect(apps, contains('allow read: if isOperator()'));
      expect(apps, contains("hasOnly(['handledAt'])"));
      expect(apps, contains('allow delete: if false'));
    });
  });

  group('what the profile says about a person', () {
    test('a claimed licence number is not a verified one', () {
      final pro = EscortPro(
        id: 'p1',
        displayName: 'יוסי א.',
        town: 'רמת גן',
        areas: const [],
        priceIls: 250,
        claimedLicence: '40115',
        createdAt: DateTime(2026, 9, 25),
      );
      expect(pro.verification, EscortVerification.selfDeclared);
      expect(pro.verificationDetail, contains('לא הוצגה תעודה'));
    });

    test('the register having answered is what makes it one', () {
      final pro = EscortPro(
        id: 'p1',
        displayName: 'יוסי א.',
        town: 'רמת גן',
        areas: const [],
        priceIls: 250,
        garageLicence: '40115',
        garageName: 'מוסך כהן ובניו',
        garageTown: 'רמת גן',
        createdAt: DateTime(2026, 9, 25),
      );
      expect(pro.verification, EscortVerification.registryListed);
      expect(pro.verificationDetail, contains('40115'));
      expect(pro.verificationDetail, contains('מוסך כהן ובניו'));
    });

    test('an approved certificate is the middle state', () {
      final pro = EscortPro(
        id: 'p1',
        displayName: 'מירב ל.',
        town: 'חולון',
        areas: const [],
        priceIls: 180,
        certStatus: CertificateStatus.approved,
        certCheckedAt: DateTime(2026, 9, 20),
        createdAt: DateTime(2026, 9, 25),
      );
      expect(pro.verification, EscortVerification.certificateChecked);
      expect(pro.verificationDetail, contains('09/2026'));
    });

    test('a rejected certificate reads as nothing proved, not as a warning', () {
      // A buyer is not told "this person was rejected" — they are told what is
      // known, which is nothing. The rejection is between the operator and the
      // applicant.
      final pro = EscortPro(
        id: 'p1',
        displayName: 'דני ש.',
        town: 'פתח תקווה',
        areas: const [],
        priceIls: 150,
        certStatus: CertificateStatus.rejected,
        createdAt: DateTime(2026, 9, 25),
      );
      expect(pro.verification, EscortVerification.selfDeclared);
    });

    test('the model never sends a checked field to the database', () {
      final map = EscortPro(
        id: 'p1',
        displayName: 'יוסי',
        town: 'רמת גן',
        areas: const [],
        priceIls: 250,
        garageLicence: '40115',
        certStatus: CertificateStatus.approved,
        createdAt: DateTime(2026, 9, 25),
      ).toFirestore();

      for (final key in [
        'garageLicence',
        'garageName',
        'garageTown',
        'certStatus',
        'certCheckedAt',
        'isHidden',
        'ratingCount',
        'ratingSum',
      ]) {
        expect(map.containsKey(key), isFalse, reason: key);
      }
    });
  });

  group('the words', () {
    final lib = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => (f.path, f.readAsStringSync()))
        .toList();

    /// Source with `//` comments removed: a comment quoting a banned phrase to
    /// explain why it is banned is not an offence.
    String code(String src) => src
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');

    test('the app never calls anybody a certified inspector', () {
      for (final (path, src) in lib) {
        for (final banned in [
          'בודק מוסמך',
          'מומחה מטעמנו',
          'בודק מאושר',
          'מוסמך על ידינו',
        ]) {
          expect(code(src).contains(banned), isFalse, reason: '$banned in $path');
        }
      }
    });

    test('it is a ליווי, not a בדיקת רכב sold by us', () {
      // "בדיקת רכב" names a licensed trade. The screens say ליווי.
      final list = File('lib/presentation/screens/escort/escort_list_screen.dart')
          .readAsStringSync();
      expect(list, contains('ליווי'));
      expect(code(list).contains('אנחנו בודקים'), isFalse);
    });

    test('the limits sit above the button, not below it', () {
      final profile =
          File('lib/presentation/screens/escort/escort_profile_screen.dart')
              .readAsStringSync();
      expect(profile.indexOf('EscortLiabilityNote'),
          lessThan(profile.indexOf('FilledButton.icon')));
    });

    test('and they say we neither chose nor employ the person', () {
      expect(EscortLiabilityNote.text, contains('אינה מעסיקה'));
      expect(EscortLiabilityNote.text, contains('לא בחרה אותו'));
      expect(EscortLiabilityNote.text, contains('התשלום מתבצע ישירות'));
    });
  });

  test('no money moves through the app', () {
    // The price is a number on a profile. Holding a buyer's payment is a
    // regulated activity and a per-job commission is what turns a platform
    // into a broker — so there is no payment path, and this is the test that
    // says so out loud.
    final repo = File('lib/data/repositories/escort_repository.dart')
        .readAsStringSync();
    // Comment-stripped, like `wording_conventions_test`: the file's own
    // doc comment explains why there is no commission, and a rule that could
    // not tell an explanation from a call site would ban the explanation.
    final code = repo
        .split(RegExp('[\r\n]+'))
        .where((l) => !l.trimLeft().startsWith('//'))
        .join(' ');
    for (final banned in ['commission', 'payment', 'charge(', 'Stripe']) {
      expect(code.contains(banned), isFalse, reason: banned);
    }
    expect(repo, contains('No money moves through here'));
  });
}
