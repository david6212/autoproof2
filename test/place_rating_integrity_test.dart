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
    // The arithmetic is executed in test/rules/place_integrity.mjs; this pins
    // the shape, so a later edit cannot quietly go back to "a review exists".
    test('every move of the aggregates demands the caller own review', () {
      final place = block('match /places/{placeId} {');
      expect(place, contains('|| aggregatesFollowOwnReview())'));
      expect(place, contains("hasAny(['ratingCount', 'ratingSum'])"));
    });

    test('and a NEW review, adding exactly its own rating', () {
      // Existence was the 26/09 hole: one review, then any number of +1/+5.
      final place = block('match /places/{placeId} {');
      expect(place, contains('(!had && has)'));
      expect(place, contains('after.ratingCount == before.ratingCount + 1'));
      expect(place, contains(
          'after.ratingSum == before.ratingSum + getAfter(r).data.rating'));
    });

    test('an edit moves the sum by new minus old, never the count', () {
      final place = block('match /places/{placeId} {');
      expect(place, contains('(had && has)'));
      expect(place, contains(
          'before.ratingSum + getAfter(r).data.rating - get(r).data.rating'));
    });

    test('the review cannot be written without the place moving with it', () {
      // Without this half, create-5 / edit-to-1 / delete netted +4.
      final reviews = block('match /reviews/{reviewUid} {');
      expect(reviews, contains('function placeMovesBy(countDelta, sumDelta)'));
      expect(reviews, contains('placeMovesBy(1, request.resource.data.rating)'));
      expect(reviews, contains('placeMovesBy(0, request.resource.data.rating'));
      expect(reviews, contains('placeMovesBy(-1, -resource.data.rating)'));
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
      expect(place, contains('(had && !has)'));
      expect(place, contains('after.ratingCount == before.ratingCount - 1'));
      expect(place, contains(
          'after.ratingSum == before.ratingSum - get(r).data.rating'));
      // A hidden review already left the aggregate; it must not leave twice.
      expect(place, contains("get(r).data.get('hiddenByOperator', false) != true"));
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
    test('takes three distinct reporters, or the operator', () {
      // A report in the caller's own name was the 26/09 hole: they write it.
      final place = block('match /places/{placeId} {');
      expect(place, contains("hasAny(['isHidden'])"));
      expect(place, contains("request.resource.data.get('reportCount', 0) >= 3"));
    });

    test('and the count rises only beside a report that is new', () {
      final place = block('match /places/{placeId} {');
      expect(place, contains('|| reportCountFollowsOwnReport())'));
      expect(place, contains('&& !exists(rep)'));
      expect(place, contains('&& existsAfter(rep)'));
      expect(place, contains("resource.data.get('reportCount', 0) + 1"));
      // And nobody creates a place that arrives already reported.
      expect(place, contains("request.resource.data.get('reportCount', 0) == 0"));
    });

    test('a report cannot be filed without moving the count', () {
      final reports = rules.substring(
          rules.indexOf('match /places/{placeId}/reports/{reporterUid}'));
      expect(reports.substring(0, reports.indexOf('allow update, delete')),
          contains(r'getAfter(/databases/$(database)/documents/places/$(placeId))'));
    });

    test('and the client still files that report before it hides', () {
      final repo = File('lib/data/repositories/place_repository.dart')
          .readAsStringSync();
      final report =
          repo.substring(repo.indexOf('Future<void> reportDoesNotExist('));
      final body = report.substring(0, report.indexOf('\n  }\n'));
      // One batch: the report, the counter and the hide stand or fall
      // together, which is the only shape the rules accept.
      expect(body, contains('final batch = _db.batch();'));
      expect(body, contains('batch.set(reportRef,'));
      expect(body, contains("'reportCount': reportCount,"));
      expect(body, contains("if (reportCount >= 3) 'isHidden': true,"));
      expect(body, contains('await batch.commit();'));
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
