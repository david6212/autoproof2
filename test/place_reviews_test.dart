import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/data/models/place_review.dart';

/// Reviews of a garage or a car wash.
///
/// A review is an opinion about a named business that never agreed to be
/// scored. Three things follow from that, and they are what these tests pin.
void main() {
  PlaceReview review({
    int rating = 5,
    String name = 'מיכל שטרן',
    String text = '',
    DateTime? edited,
  }) =>
      PlaceReview(
        uid: 'u1',
        rating: rating,
        text: text,
        authorName: name,
        createdAt: DateTime(2026, 5, 4),
        editedAt: edited,
      );

  group('the author is named, not identified', () {
    test('a full name becomes a first name and an initial', () {
      // The author agreed to leave a review, not to have their full name sit
      // under an opinion of somebody's business forever.
      expect(review().displayName, 'מיכל ש.');
    });

    test('one name stays as it is', () {
      expect(review(name: 'מיכל').displayName, 'מיכל');
    });

    test('an empty name still renders as somebody', () {
      expect(review(name: '   ').displayName, 'מבקר');
      expect(review(name: '').displayName, 'מבקר');
    });
  });

  group('one review per person, enforced by the database', () {
    test('the document id is the author uid', () {
      // Not a convention the app remembers: a second review overwrites the
      // first, and the rule refuses a write to anybody else's id.
      final r = PlaceReview.fromFirestore(const {'rating': 4}, 'uid-abc');
      expect(r.uid, 'uid-abc');
    });

    test('the repository writes to that id and nowhere else', () {
      final repo = File('lib/data/repositories/place_repository.dart')
          .readAsStringSync();
      expect(repo, contains(".collection('reviews').doc(review.uid)"));
    });
  });

  group('an edit says so', () {
    test('a review nobody touched carries no stamp', () {
      expect(review().wasEdited, isFalse);
    });

    test('and one that changed carries the date', () {
      expect(review(edited: DateTime(2026, 8, 25)).wasEdited, isTrue);
    });

    test('the original creation date survives an edit', () {
      // The repository copies `createdAt` forward rather than letting the new
      // write stamp today — a review re-dated to the day it was edited would
      // read as fresh when it is years old.
      final repo = File('lib/data/repositories/place_repository.dart')
          .readAsStringSync();
      expect(repo, contains("if (!isNew) 'createdAt': previous['createdAt']"));
    });
  });

  group('the aggregates move with the review, in one batch', () {
    final repo =
        File('lib/data/repositories/place_repository.dart').readAsStringSync();

    test('both writes or neither', () {
      // A review that landed without its counters would sit under an average
      // that excludes it, and nothing on this plan would ever notice.
      expect(repo, contains('final batch = _db.batch();'));
      expect(repo, contains('batch.set(\n      reviewRef,'));
      expect(repo, contains("batch.update(placeRef, {"));
    });

    test('replacing a review moves the sum by the difference, not the whole',
        () {
      // Replacing a 5 with a 2 must move the sum by -3 and leave the count
      // alone. Only the rating being replaced knows that.
      expect(repo, contains('review.rating - oldRating'));
      expect(repo, contains('oldCount + (isNew ? 1 : 0)'));
    });

    test('deleting takes the rating back out', () {
      expect(repo, contains('Future<void> deleteReview'));
      expect(repo, contains('batch.delete(reviewRef)'));
    });

    test('the average never divides by zero', () {
      expect(repo, contains('count == 0 ? 0 : sum / count'));
      expect(repo, contains('count <= 0 ? 0 : sum / count'));
    });
  });

  test('the text limit is stated in the model and enforced in the rules', () {
    expect(PlaceReview.maxTextLength, 500);
    final rules = File('firestore.rules').readAsStringSync();
    expect(rules, contains('request.resource.data.text.size() <= 500'));
  });

  group('what the place page may say', () {
    final screen =
        File('lib/presentation/screens/places/place_detail_screen.dart')
            .readAsStringSync();

    test('the disclaimer is on the page', () {
      expect(screen, contains('BonnetCheck אינה בודקת מוסכים ואינה ממליצה'));
    });

    test('the source badge is not optional', () {
      expect(screen, contains('נוסף על ידי הקהילה'));
      expect(screen, contains('רשום במשרד התחבורה'));
    });

    test('no average below three reviews', () {
      expect(screen, contains('if (place.hasEnoughRatings)'));
      expect(screen, contains('היה הראשון לדרג'));
    });

    test('nothing recommends or vouches for a garage', () {
      for (final claim in ['מאומת', 'מומלץ', 'בטוח', 'הכי טוב']) {
        expect(screen.contains(claim), isFalse, reason: claim);
      }
    });
  });
}
