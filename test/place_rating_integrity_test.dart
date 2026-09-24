import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/data/models/place.dart';

/// SEC-01 and SEC-02: a garage's score, and its existence in the directory.
///
/// One rule governed both, and it was open. `ratingAvg` was in the writable
/// list with nothing bounding it, so one write set any garage in the country to
/// 5.0 stars with no review behind it. `isHidden` was in the same list with
/// nothing requiring the three reports the client counts, so one write removed
/// any garage from the directory — irreversibly, because delete is refused and
/// hiding was one-way even for the operator.
///
/// Both are written about a real business with a name, which is why these are
/// the holes that mattered most in the 24/09 scan.
void main() {
  final rules = File('firestore.rules').readAsStringSync();

  String block(String header) {
    final start = rules.indexOf(header);
    expect(start, greaterThan(-1), reason: header);
    final after = rules.indexOf('match /', start + 8);
    return after == -1 ? rules.substring(start) : rules.substring(start, after);
  }

  group('the score cannot be written without the review behind it', () {
    test('every move of the aggregates demands the caller own review', () {
      final place = block('match /places/{placeId} {');
      expect(place, contains('ownReviewAfter(placeId)'));
      expect(place, contains("hasAny(['ratingCount', 'ratingSum', 'ratingAvg'])"));
    });

    test('and the installed client still passes it', () {
      // saveReview writes the review document and the place aggregate in ONE
      // batch. That is what makes this rule shippable without an app release
      // first — if the write were split, every existing install would start
      // failing to save a review.
      final repo = File('lib/data/repositories/place_repository.dart')
          .readAsStringSync();
      final save = repo.substring(repo.indexOf('Future<void> saveReview('));
      final body = save.substring(0, save.indexOf('\n  }\n'));
      expect(body, contains('_db.batch()'));
      expect(body, contains('batch.set(\n      reviewRef,'));
      expect(body, contains('batch.update(placeRef'));
    });

    test('withdrawing a review is still allowed', () {
      // The other side of the same rule: the count falls when the caller's own
      // review disappears in the same write. This is also their right to
      // erasure, and it was broken once before by a rule that forbade any
      // decrement at all.
      final place = block('match /places/{placeId} {');
      expect(place, contains('!existsAfter(/databases/'));
    });
  });

  group('the stored average is no longer believed', () {
    test('a forged ratingAvg renders as the real one', () {
      // Old installs still show the stored field and the repository still
      // writes it, so the rules cannot simply forbid it. What this app can do
      // is stop reading it: the score on screen is the sum over the count.
      final place = Place.fromFirestore(
        {
          'name': 'מוסך כהן',
          'category': 'garage_mechanical',
          'ratingCount': 3,
          'ratingSum': 6,
          // What an attacker wrote.
          'ratingAvg': 5.0,
        },
        'p1',
      );

      expect(place.ratingAvg, 2.0);
    });

    test('and an empty place is not a division by zero', () {
      final place = Place.fromFirestore(
        {'name': 'מוסך', 'category': 'garage_mechanical'},
        'p2',
      );
      expect(place.ratingAvg, 0);
      expect(place.hasEnoughRatings, isFalse);
    });
  });

  group('removing a garage from the directory', () {
    test('takes a report in the caller name, or the operator', () {
      final place = block('match /places/{placeId} {');
      expect(place, contains('ownReport(placeId)'));
      expect(place, contains("hasAny(['isHidden'])"));
    });

    test('and the client still files that report before it hides', () {
      final repo = File('lib/data/repositories/place_repository.dart')
          .readAsStringSync();
      final report =
          repo.substring(repo.indexOf('Future<void> reportDoesNotExist('));
      final body = report.substring(0, report.indexOf('\n  }\n'));
      expect(body.indexOf('reportRef.set('),
          lessThan(body.indexOf("update({'isHidden': true})")),
          reason: 'the report must exist before the hide, or the rule refuses');
    });

    test('the operator can undo a hide that was wrong', () {
      // Hiding stays one-way for everybody else — an entry three people say
      // does not exist should not come back because a fourth disagrees — but
      // before this, a mistaken removal was permanent and console-only.
      final place = block('match /places/{placeId} {');
      // The open paren matters: `request.resource.data.isHidden == false` in
      // the create clause contains the same text, and slicing from there reads
      // the wrong rule.
      final oneWay =
          place.substring(place.indexOf('(resource.data.isHidden == false'));
      expect(oneWay.substring(0, 400), contains('|| isOperator()'));
    });
  });
}
