import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The four holes closed on 29/08, pinned so they cannot quietly reopen.
///
/// Each of these was found by reading the rules against what the app actually
/// writes, and each was exploitable from a REST client by someone who had done
/// nothing but sign up. They are grouped in one file because they share a
/// shape: a rule that authorised the *actor* and forgot to check the *object*.
void main() {
  final rules = File('firestore.rules').readAsStringSync();

  /// Everything between `match <path> {` and the matching close, so an
  /// assertion about one collection cannot be satisfied by a line belonging to
  /// another. Brace-counted rather than regex-matched, because these blocks
  /// nest several levels deep.
  String block(String matchPath) {
    // Plain throws rather than expect(): this helper is called from group
    // bodies as well as tests, and expect() outside a test is an error in
    // itself, which would mask whatever it was about to tell us.
    final start = rules.indexOf('match $matchPath {');
    if (start < 0) throw StateError('no rule for $matchPath');
    // Count from the brace that OPENS the block, not from the start of the
    // line: a match path contains braces of its own ({plate}, {snapshotId}),
    // and counting through them closes the block before it has begun.
    final bodyStart = rules.indexOf('{', start + 'match $matchPath'.length);
    var depth = 0;
    for (var i = bodyStart; i < rules.length; i++) {
      if (rules[i] == '{') depth++;
      if (rules[i] == '}') {
        depth--;
        if (depth == 0) return rules.substring(start, i + 1);
      }
    }
    throw StateError('unbalanced braces after $matchPath');
  }

  group('a shared licence is never readable anonymously', () {
    // The document carries an Israeli ID number and a home address. Google
    // Play prohibits publicly disclosing a government identification number
    // outright — there is no exception for the owner having agreed, so the
    // in-app warning dialog does not cure it. Signing in does not make the
    // document private; it stops it being *public*, and "public" is the word
    // the prohibition turns on.
    //
    // The rest of the marketplace is deliberately browsable signed out —
    // `services` short-circuits for a guest on purpose — which is exactly why
    // this needs its own test rather than trusting the surrounding style.

    test('the record requires a sign-in on the shared branch', () {
      final documents = block('/documents/{documentId}');
      final read = documents.substring(
          documents.indexOf('allow read:'), documents.indexOf('allow create:'));

      expect(read.contains('isSharedWithBuyers'), isTrue);
      expect('isSignedIn()'.allMatches(read).length, 2,
          reason: 'both branches — the shared one and the owner one');
    });

    test('the bytes carry the same rule as the record', () {
      // A file readable when its record is not would make the sharing switch
      // decorative; rules are not inherited by subcollections, so this has to
      // be restated rather than assumed.
      final file = block('/file/{fileId}');
      final read =
          file.substring(file.indexOf('allow read:'), file.indexOf('allow write:'));

      expect(read.contains('isSharedWithBuyers'), isTrue);
      expect('isSignedIn()'.allMatches(read).length, 2);
    });
  });

  group('a handover code only moves the car of whoever minted it', () {
    // Before this, `transfers` create asked who you were and never what you
    // owned. A stranger read `vehicleId` off any public listing, minted a
    // transfer naming that vehicle with themselves as `fromUserId`, then
    // claimed the passport: three writes, no app, and the real owner was
    // locked out with no way back — deleting a vehicle needs serviceCount 0,
    // and the cars worth stealing are the documented ones.

    test('minting a transfer proves ownership of the vehicle it names', () {
      final transfers = block('/transfers/{claimCode}');
      final create = transfers.substring(transfers.indexOf('allow create:'),
          transfers.indexOf('allow update:'));

      expect(create, contains('vehicleData(request.resource.data.vehicleId)'));
      expect(create, contains('== request.auth.uid'));
    });

    test('the claim checks the code against the CURRENT owner', () {
      // The load-bearing line. Every other clause in isValidClaim can be
      // satisfied from a public listing: `previousOwnerId` is copied off it,
      // and the attacker chooses their own expiry.
      final claim = rules.substring(rules.indexOf('function isValidClaim'),
          rules.indexOf('function transferData'));

      expect(claim, contains('.fromUserId'));
      expect(claim, contains('resource.data.ownerId'));
    });

    test('a code cannot be minted to last forever', () {
      final transfers = block('/transfers/{claimCode}');
      expect(transfers, contains('duration.value(15'),
          reason: 'validFor is 14 days; the slack absorbs a fast client clock');
    });
  });

  group('plate history cannot be forged', () {
    // A plate is on every windscreen in the street, and this collection had no
    // field validation at all — no bounds, no server timestamp, no link to a
    // listing. A planted record is copied verbatim onto the honest owner's
    // public page when they publish, and since 27/08 raises THREE findings
    // there, one of which names a real third party's live listing.
    //
    // There is no update and no delete, so the victim cannot take it back.
    // That is the reason every field is checked on the way in.

    final snapshots = block('/plate_history/{plate}/snapshots/{snapshotId}');

    test('a snapshot must come from a listing the writer published', () {
      expect(snapshots, contains('carSellerId(request.resource.data.carId)'));
      expect(snapshots, contains('== request.auth.uid'));
    });

    test('the date is the server clock, not the writer choice', () {
      // A backdated snapshot is what invents a "dealer flip" inside the
      // relisting detector flip window.
      expect(snapshots, contains('createdAt == request.time'));
    });

    test('mileage, price and seller type are all bounded', () {
      expect(snapshots, contains('km is int'));
      expect(snapshots, contains('km <= 2000000'));
      expect(snapshots, contains('price > 0'));
      for (final type in const ['private', 'agent', 'dealer']) {
        expect(snapshots, contains("'$type'"),
            reason: 'every SellerType, and nothing else');
      }
    });

    test('it stays append-only', () {
      expect(snapshots, contains('allow update, delete: if false'));
    });
  });

  group('leaving takes the data with it', () {
    // Two deliberate designs collided here. Service history is append-only so
    // a seller cannot erase an inconvenient record while a buyer reads it; the
    // right to erasure says a person may take their data when they go. The
    // only thing separating them is whether the account still exists — so the
    // profile document is deleted first, and the rules key the exception on
    // its absence. Laundering a history this way costs the whole account.

    test('the erasure signal is the absence of the user document', () {
      final fn = rules.substring(rules.indexOf('function isErasingAccount'),
          rules.indexOf('function transferData'));
      expect(fn, contains('!exists('));
      expect(fn, contains('users/\$(request.auth.uid)'));
    });

    test('a service record is still undeletable by a live account', () {
      final services = block('/services/{serviceId}');
      final delete = services.substring(services.indexOf('allow delete:'));

      expect(delete, contains('isErasingAccount()'));
      expect(delete, contains('ownerId == request.auth.uid'),
          reason: 'and only from the owner of that passport');
      expect(delete.contains('if true'), isFalse);
    });

    test('a documented passport is deletable only while erasing', () {
      final vehicles = block('/vehicles/{vehicleId}');
      final delete = vehicles.substring(vehicles.indexOf('allow delete:'),
          vehicles.indexOf('// ---- Service records'));

      expect(delete, contains('serviceCount == 0'),
          reason: 'the ordinary rule survives');
      expect(delete, contains('isErasingAccount()'));
    });
  });

  group('the deletion actually reaches the subcollections', () {
    // A Firestore document delete does not touch its subcollections. The old
    // code was a plain `.delete()` on cars and vehicles, so the licence scan,
    // the service history, the running costs and — under `cars/{id}/private` —
    // the plate all survived an account deletion the privacy policy described
    // as complete.
    final repo = File('lib/data/repositories/account_deletion_repository.dart')
        .readAsStringSync();

    test('every subcollection is named explicitly', () {
      for (final sub in const [
        'saved',
        'past_vehicles',
        'services',
        'reminders',
        'expenses',
        'documents',
        'private',
        'journeys',
        'buyer_likes',
        'seller_likes',
        'notes',
      ]) {
        expect(repo, contains("'$sub'"), reason: '$sub would be left behind');
      }
      expect(repo, contains("collection('file')"),
          reason: 'the bytes live one level below the document record');
    });

    test('the profile document goes before everything it authorises', () {
      final profile = repo.indexOf("collection('users').doc(uid).delete()");
      final vehicles = repo.indexOf("collection('vehicles')");
      final credential = repo.indexOf('user.delete()');

      expect(profile, greaterThan(-1));
      expect(profile, lessThan(vehicles),
          reason: 'it is what tells the rules this is an erasure');
      expect(credential, greaterThan(vehicles),
          reason: 'the credential is last, or the uid the rules need is gone');
    });

    test('children are deleted before their parent', () {
      // Not only so nothing is orphaned: several child rules authorise through
      // a get() on the parent, so a parent deleted first makes its children
      // undeletable by anyone, permanently.
      final fileBytes = repo.indexOf("collection('file')");
      final documentRecord = repo.indexOf('await document.reference.delete()');
      final vehicleDoc = repo.indexOf('await vehicle.reference.delete()');

      expect(fileBytes, lessThan(documentRecord));
      expect(documentRecord, lessThan(vehicleDoc));
    });
  });
}
