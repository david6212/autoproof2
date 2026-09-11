import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/data/models/place_review.dart';
import 'package:bonnetcheck/data/repositories/operator_inbox_repository.dart';

/// Reporting and hiding garage reviews.
///
/// Car notes are a closed bank of findings, so nothing in them can call a
/// seller a crook. Garage reviews are not: they are free text, up to 500
/// characters, about a real business with a name. Until this change nobody
/// could report one, and the operator could not remove one either — the rules
/// let only its author delete it. In defamation a platform's exposure tends to
/// grow once it has been told and has not acted, and there was no way to tell
/// it and no way for it to act.
void main() {
  final rules = File('firestore.rules').readAsStringSync();
  final repo = File('lib/data/repositories/place_repository.dart')
      .readAsStringSync();
  final screen = File('lib/presentation/screens/places/place_detail_screen.dart')
      .readAsStringSync();

  String block(String header) {
    final start = rules.indexOf(header);
    expect(start, greaterThan(-1), reason: header);
    final after = rules.indexOf('match /', start + 8);
    return after == -1 ? rules.substring(start) : rules.substring(start, after);
  }

  group('the bug that was already there', () {
    test('an author can withdraw their own review again', () {
      // The aggregate rule required the count never to fall. deleteReview
      // lowers it, a batch is atomic, so the rule refused the whole batch —
      // and the review delete with it. Nobody could withdraw a review, which
      // is also their right to erasure.
      final place = block('match /places/{placeId} {');
      expect(place, contains('existsAfter('),
          reason: 'a decrement is tied to the caller deleting their own review');
      expect(
        place,
        contains('request.resource.data.ratingCount <= resource.data.ratingCount + 1'),
      );
    });

    test('but nobody can lower a competitor\'s rating', () {
      // The naive fix — allow -1 — would have let any signed-in account drag
      // a garage's rating down one write at a time. The decrement is allowed
      // only when the caller's own review disappears in the same batch, or
      // for the operator.
      final place = block('match /places/{placeId} {');
      expect(place, contains('exists(/databases/'));
      expect(place, contains('!existsAfter(/databases/'));
      expect(place, contains('|| isOperator()'));
    });
  });

  group('reporting a review', () {
    test('lives at the top level beside the other two inbox collections', () {
      // One inbox reads all three. Nested under a place it would need a
      // collection-group query and a recursive rule to do the same.
      expect(rules, contains('    match /review_reports/{reportId} {'));
    });

    test('one report per person per review', () {
      // The id ends in the reporter's uid; a second report is an update, and
      // only the operator may update a report.
      final r = block('match /review_reports/{reportId}');
      expect(r, contains("reportId.matches('.*__' + request.auth.uid)"));
      expect(r, contains('allow read: if isOperator()'));
      expect(r, contains('allow delete: if false'));
      expect(repo, contains(r"'${placeId}__${reviewUid}__$reporterUid'"));
    });

    test('a duplicate is said to be a duplicate', () {
      // Not pretended to be a fresh report.
      expect(repo, contains('if ((await ref.get()).exists) return false;'));
    });

    test('lands in the operator inbox under the same fourteen days', () {
      expect(InboxKind.values, contains(InboxKind.reviewReport));
      expect(InboxKind.reviewReport.collection, 'review_reports');
    });

    test('the button is on other people\'s reviews', () {
      expect(screen, contains('_report(context, ref)'));
      expect(screen, contains('if (!isMine || isOperator)'));
    });
  });

  group('hiding a review', () {
    test('hides, never deletes', () {
      // The words stay exactly as written. A report that turns out to be
      // wrong is undone with the review intact; one that turns out to be
      // defamatory keeps the text as the record of what was published.
      final hide = repo.substring(repo.indexOf('Future<void> _setHidden('));
      final body = hide.substring(0, hide.indexOf('\n  }\n'));
      expect(body.contains('.delete('), isFalse);
      expect(body, contains("'hiddenByOperator': hidden"));
    });

    test('and takes its rating out of the average', () {
      // A report usually says the review is not legitimate. A hidden one-star
      // that still dragged the score down would be moderation in name only.
      final hide = repo.substring(repo.indexOf('Future<void> _setHidden('));
      expect(hide, contains('hidden ? oldCount - 1 : oldCount + 1'));
    });

    test('the operator may change the flag and nothing else', () {
      final reviews = block('match /reviews/{reviewUid}');
      expect(reviews,
          contains("hasOnly(['hiddenByOperator', 'hiddenAt'])"));
    });

    test('a hidden review is frozen for its author', () {
      // saveReview writes the whole document. Without this, editing a hidden
      // review would silently drop the flag and put back on screen the very
      // review somebody reported — restored by the person who wrote it.
      final reviews = block('match /reviews/{reviewUid}');
      expect(reviews,
          contains("resource.data.get('hiddenByOperator', false) != true"));
      expect(reviews,
          contains("!('hiddenByOperator' in request.resource.data)"));
    });

    test('deleting a hidden review does not lower the score twice', () {
      // Its rating left the aggregate when it was hidden.
      final del = repo.substring(repo.indexOf('Future<void> deleteReview('));
      expect(del, contains("if (data['hiddenByOperator'] == true)"));
    });

    test('hiding twice does not move the average twice', () {
      final hide = repo.substring(repo.indexOf('Future<void> _setHidden('));
      expect(hide, contains("if ((review['hiddenByOperator'] == true) == hidden) return;"));
    });
  });

  group('who sees a hidden review', () {
    test('nobody but the operator is even sent one', () {
      expect(repo, contains('removeWhere((r) => r.hiddenByOperator && !includeHidden)'));
      final provider =
          File('lib/presentation/providers/place_provider.dart').readAsStringSync();
      expect(provider, contains('includeHidden: ref.watch(isOperatorProvider)'));
    });

    test('a review written before moderation existed stays shown', () {
      final r = PlaceReview.fromFirestore(
        {
          'rating': 4,
          'text': 'x',
          'authorName': 'a',
          // A Timestamp, as Firestore actually returns — the parser calls
          // toDate() on it.
          'createdAt': Timestamp.fromDate(DateTime(2026)),
        },
        'u1',
      );
      expect(r.hiddenByOperator, isFalse,
          reason: 'absent means shown, and must not become hidden by being read');
    });

    test('the author can never write the flag', () {
      // It is read, and never sent by toFirestore — the rules refuse an author
      // write that carries it.
      final model =
          File('lib/data/models/place_review.dart').readAsStringSync();
      // The method, not the first mention: the field's own doc comment names
      // [toFirestore] first, and slicing from there sweeps in fromFirestore,
      // which reads the flag on purpose.
      final to = model.substring(model.indexOf('Map<String, dynamic> toFirestore'));
      expect(to.contains("'hiddenByOperator'"), isFalse);
    });
  });
}
