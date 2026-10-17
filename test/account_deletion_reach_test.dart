import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/data/repositories/account_deletion_repository.dart';

/// "Delete my account" EXECUTED, not string-matched.
///
/// `account_deletion_test.dart` reads the repository as text, which is how two
/// gaps survived it: the invoice image one level below every service record
/// (SEC-17), and everything written on other people's listings and places —
/// including a note and a review that carried the author's full name (SEC-18,
/// SEC-19). This runs the real `deleteEverything()` against an in-memory
/// database holding one of everything, and checks both halves: what was mine
/// is gone, and what was somebody else's is still exactly there.
///
/// The rules side of the same sequence — that each step is PERMITTED — is
/// executed against the emulator in test/rules/account_erasure.mjs.
void main() {
  const me = 'me-uid';
  const other = 'other-uid';

  late FakeFirebaseFirestore db;
  late AccountDeletionRepository repo;

  // What the injected Storage sweep saw when it ran (SEC-04).
  String? sweptUid;
  bool? profileGoneAtSweep;
  bool? listingStillThereAtSweep;

  Future<bool> exists(String path) async => (await db.doc(path).get()).exists;

  setUp(() async {
    db = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: me, email: 'me@example.com'),
    );
    sweptUid = null;
    repo = AccountDeletionRepository(
      auth: auth,
      firestore: db,
      sweepStorage: (uid) async {
        sweptUid = uid;
        profileGoneAtSweep = !await exists('users/$uid');
        listingStillThereAtSweep = await exists('cars/mine');
      },
    );

    // ---- mine ----
    await db.doc('users/$me').set({'name': 'דוד'});
    await db.doc('cars/mine').set({'sellerId': me, 'photos': ['p.jpg']});
    await db.doc('vehicles/v1').set({'ownerId': me, 'serviceCount': 1});
    await db.doc('vehicles/v1/services/s1').set({'addedByOwnerId': me});
    await db.doc('vehicles/v1/services/s1/file/blob').set({'bytes': 'invoice'});
    await db.doc('vehicles/v1/documents/d1').set({'kind': 'licence'});
    await db.doc('vehicles/v1/documents/d1/file/f1').set({'bytes': 'scan'});

    // ---- somebody else's listing and place, with my traces on them ----
    await db.doc('cars/theirs').set({'sellerId': other});
    await db.doc('cars/theirs/notes/n-mine').set({
      'authorUid': me,
      'authorName': 'דוד מ.',
    });
    await db.doc('cars/theirs/notes/n-theirs').set({
      'authorUid': other,
      'authorName': 'רון',
    });
    await db.doc('cars/theirs/buyer_likes/$me').set({'uid': me});
    await db.doc('cars/theirs/buyer_likes/$other').set({'uid': other});
    await db.doc('cars/theirs/journeys/$me').set({'uid': me, 'stage': 2});

    // A place with two reviews: mine (5) and theirs (3), and one hidden one
    // of mine on a second place, whose rating already left the score.
    await db.doc('places/p1').set({'ratingCount': 2, 'ratingSum': 8});
    await db.doc('places/p1/reviews/$me').set({
      'authorUid': me,
      'authorName': 'דוד מ.',
      'rating': 5,
    });
    await db.doc('places/p1/reviews/$other').set({
      'authorUid': other,
      'authorName': 'רון',
      'rating': 3,
    });
    await db.doc('places/p2').set({'ratingCount': 0, 'ratingSum': 0});
    await db.doc('places/p2/reviews/$me').set({
      'authorUid': me,
      'rating': 1,
      'hiddenByOperator': true,
    });
    await db.doc('places/p1/reports/$me').set({'reporterUid': me});
    await db.doc('fuel_reports/st1/prices/$me').set({'uid': me, 'agorot': 700});
    await db.doc('fuel_reports/st1/prices/$other').set({'uid': other, 'agorot': 710});
    await db.doc('escort_pros/$me').set({'displayName': 'דוד', 'town': 'חיפה'});
    await db.doc('pro_applications/$me').set({'reporterUid': me, 'claimedLicence': '123'});
    await db.doc('places/p1/reports/$other').set({'reporterUid': other});

    await repo.deleteEverything();
  });

  group('what was mine is gone', () {
    test('my listing', () async {
      expect(await exists('cars/mine'), isFalse);
    });

    test('my files in Storage — swept after the profile, before the listing',
        () async {
      // Before the listing: with its record gone nothing could ever find a
      // photo again, in a prefix the bucket makes publicly listable (SEC-04).
      expect(sweptUid, me);
      expect(profileGoneAtSweep, isTrue);
      expect(listingStillThereAtSweep, isTrue);
    });

    test('the invoice image under a service record (SEC-17)', () async {
      expect(await exists('vehicles/v1/services/s1/file/blob'), isFalse);
      expect(await exists('vehicles/v1/services/s1'), isFalse);
    });

    test('the licence scan, and the passport above it', () async {
      expect(await exists('vehicles/v1/documents/d1/file/f1'), isFalse);
      expect(await exists('vehicles/v1'), isFalse);
      expect(await exists('users/$me'), isFalse);
    });

    test('a note on somebody else\'s listing (SEC-18)', () async {
      expect(await exists('cars/theirs/notes/n-mine'), isFalse);
    });

    test('a like and a journey on somebody else\'s listing', () async {
      expect(await exists('cars/theirs/buyer_likes/$me'), isFalse);
      expect(await exists('cars/theirs/journeys/$me'), isFalse);
    });

    test('a garage review, with its rating taken back out (SEC-19)', () async {
      expect(await exists('places/p1/reviews/$me'), isFalse);
      final p1 = (await db.doc('places/p1').get()).data()!;
      expect(p1['ratingCount'], 1);
      expect(p1['ratingSum'], 3, reason: 'only the other review remains');
    });

    test('a hidden review goes without moving the score twice', () async {
      expect(await exists('places/p2/reviews/$me'), isFalse);
      final p2 = (await db.doc('places/p2').get()).data()!;
      expect(p2['ratingCount'], 0);
      expect(p2['ratingSum'], 0);
    });

    test('a "does not exist" report', () async {
      expect(await exists('places/p1/reports/$me'), isFalse);
    });

    test('a fuel price report', () async {
      expect(await exists('fuel_reports/st1/prices/$me'), isFalse);
    });

    test('a professional profile and its application (SEC-27)', () async {
      expect(await exists('escort_pros/$me'), isFalse);
      expect(await exists('pro_applications/$me'), isFalse);
    });
  });

  group('what was somebody else\'s is untouched', () {
    test('their listing, their note, their like', () async {
      expect(await exists('cars/theirs'), isTrue);
      expect(await exists('cars/theirs/notes/n-theirs'), isTrue);
      expect(await exists('cars/theirs/buyer_likes/$other'), isTrue);
    });

    test('their fuel price', () async {
      expect(await exists('fuel_reports/st1/prices/$other'), isTrue);
    });

    test('their review and their report', () async {
      expect(await exists('places/p1/reviews/$other'), isTrue);
      expect(await exists('places/p1/reports/$other'), isTrue);
      expect(await exists('places/p1'), isTrue);
    });
  });
}
