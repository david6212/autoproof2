import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Hiding a place that does not exist.
///
/// **The spec's design could not work as written.** It put reports in a
/// top-level `place_reports` with `allow read: if false`, and then had the
/// client count them to decide when to hide. A collection nobody may read
/// cannot be counted by the client that is told to count it.
///
/// They live under the place instead, keyed by reporter and readable. What
/// that reveals is which places were reported and by how many uids — no names,
/// no reasons about people. Keying by uid also does what a top-level
/// collection could not: one report per person, enforced by the database, so
/// nobody hides a rival on their own.
void main() {
  final rules = File('firestore.rules').readAsStringSync();
  final repo =
      File('lib/data/repositories/place_repository.dart').readAsStringSync();

  group('one report per person', () {
    test('the document key is the reporter', () {
      expect(rules, contains('match /places/{placeId}/reports/{reporterUid}'));
      expect(rules, contains('request.auth.uid == reporterUid'));
    });

    test('and the repository writes to that key', () {
      expect(repo, contains(".collection('reports').doc(uid)"));
    });

    test('a report cannot be withdrawn or edited', () {
      // Withdrawing one after it has hidden a place would leave the place
      // hidden with nothing on record explaining why.
      final block = rules.substring(
          rules.indexOf('match /places/{placeId}/reports/{reporterUid}'));
      expect(block, contains('allow update, delete: if false'));
    });
  });

  group('three is the threshold, and the third reporter acts on it', () {
    test('the count includes the report just filed', () {
      // Counted after the write, so the third person to file is the one who
      // hides it — not the fourth.
      final method = repo.substring(repo.indexOf('reportDoesNotExist'));
      final write = method.indexOf('reportRef.set');
      final count = method.indexOf("collection('reports').get()");
      expect(write, greaterThan(-1));
      expect(count, greaterThan(write), reason: 'write first, then count');
    });

    test('three hides it', () {
      expect(repo, contains('reports.docs.length >= 3'));
      expect(repo, contains("update({'isHidden': true})"));
    });

    test('hiding is one-way in the rules', () {
      final block = rules.substring(rules.indexOf('match /places/{placeId}'));
      expect(block, contains('request.resource.data.isHidden == true'));
    });
  });

  group('hidden means gone from the lists, not deleted', () {
    test('search skips hidden entries', () {
      expect(repo, contains('if (!place.isHidden) results[place.id] = place'));
    });

    test('so does a category listing', () {
      expect(repo, contains("where('isHidden', isEqualTo: false)"));
    });

    test('and nothing can delete the place itself', () {
      final block = rules.substring(rules.indexOf('match /places/{placeId}'));
      expect(block, contains('allow delete: if false'));
    });
  });

  test('only community entries can be reported', () {
    // There is nothing useful a reader can tell us about an official register,
    // and a report button on one would read as a complaint box about the
    // business.
    final screen =
        File('lib/presentation/screens/places/place_detail_screen.dart')
            .readAsStringSync();
    final row = screen.substring(screen.indexOf('class _ReportRow'));
    expect(row, contains('if (!place.isCommunity) return const SizedBox.shrink()'));
  });

  test('adding a place says it is unverified before the write', () {
    // After the fact is too late for somebody who did not mean to publish.
    final add = File('lib/presentation/screens/places/add_place_screen.dart')
        .readAsStringSync();
    final save = add.indexOf('Future<void> _save()');
    final dialog = add.indexOf('להוסיף לרשימה?', save);
    final write = add.indexOf('addCommunityPlace', save);
    expect(dialog, greaterThan(-1));
    expect(write, greaterThan(dialog), reason: 'ask first, then write');
  });
}
