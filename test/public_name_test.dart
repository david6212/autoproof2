import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/core/utils/public_name.dart';
import 'package:bonnetcheck/data/models/place_review.dart';

/// SEC-18 and SEC-19: a world-readable document carries "מיכל ש.", never
/// "מיכל שפירא".
///
/// The screen already showed the short form; the documents under it stored
/// the Google display name in full, readable without an account. Shortening
/// on screen while shipping the surname in the document is decoration.
void main() {
  // The same regex the rules apply, run here so the two halves cannot drift:
  // `matches()` in the rules is a full match, so this one is anchored.
  final rule = RegExp('^$publicNamePattern\$');

  group('publicName', () {
    test('a first name and a surname become a first name and an initial', () {
      expect(publicName('מיכל שפירא'), 'מיכל ש.');
    });

    test('a middle name and a surname are not both kept', () {
      expect(publicName('דוד בן עמי'), 'דוד ב.');
    });

    test('one word stays one word', () {
      expect(publicName('רון'), 'רון');
    });

    test('nothing usable becomes the fallback, never an empty string', () {
      expect(publicName(''), fallbackPublicName);
      expect(publicName('   '), fallbackPublicName);
    });

    test('an initial is one character, even outside the BMP', () {
      expect(publicName('Dana 😀x'), 'Dana 😀.');
    });

    test('a very long first name is cut to fit the rule', () {
      final long = 'א' * 50;
      expect(publicName(long).runes.length, maxFirstNameLength);
    });

    test('every output passes the rule', () {
      for (final raw in [
        'מיכל שפירא',
        'דוד בן עמי',
        'רון',
        '',
        'א' * 50,
        'Mary-Jane O\'Neil Smith',
      ]) {
        expect(rule.hasMatch(publicName(raw)), isTrue, reason: raw);
      }
    });

    test('and a full name does not', () {
      expect(rule.hasMatch('מיכל שפירא'), isFalse);
      expect(rule.hasMatch('דוד מ. כהן'), isFalse);
    });
  });

  group('the writers store it', () {
    test('a review document carries the short form and its author uid', () {
      final review = PlaceReview(
        uid: 'u1',
        rating: 4,
        authorName: publicName('מיכל שפירא'),
        createdAt: DateTime(2026, 10, 1),
      );
      final doc = review.toFirestore();
      expect(doc['authorName'], 'מיכל ש.');
      expect(doc['authorUid'], 'u1');
    });

    test('a legacy review with the full name still renders shortened', () {
      final review = PlaceReview(
        uid: 'u1',
        rating: 4,
        authorName: 'מיכל שפירא',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(review.displayName, 'מיכל ש.');
    });

    test('both providers shorten before writing', () {
      for (final f in [
        'lib/presentation/providers/cars_provider.dart',
        'lib/presentation/providers/place_provider.dart',
      ]) {
        expect(File(f).readAsStringSync(),
            contains('authorName: publicName(name)'), reason: f);
      }
    });

    test('the note card renders legacy notes shortened too', () {
      final card = File('lib/presentation/widgets/car_notes_section.dart')
          .readAsStringSync();
      expect(card, contains('publicName(note.authorName)'));
      expect(card, isNot(contains('Text(note.authorName')));
    });
  });

  test('the rules apply the same pattern to notes and reviews', () {
    final rules = File('firestore.rules').readAsStringSync();
    expect(rules, contains("name.matches('$publicNamePattern')"));
    expect(rules, contains(
        'isPublicName(request.resource.data.authorName)'));
    expect(rules, contains('function reviewIdentifiesItsAuthor()'));
  });
}
