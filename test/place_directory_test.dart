import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/data/models/place.dart';

/// The garage and car-wash directory, stage 1.
///
/// **It has no `inspection` category, and that is the load-bearing decision.**
/// Licensed inspection centres already exist in this app — an asset from
/// Ministry of Transport data with its own screen. Repeating them here would
/// give the same centres two homes, and the community copy would drift from
/// the official one the first time somebody edited it.
void main() {
  group('what the directory covers', () {
    test('garages and washes, never inspection centres', () {
      final ids = PlaceCategory.values.map((c) => c.id).toList();
      expect(ids, contains('garage_mechanical'));
      expect(ids, contains('car_wash'));
      expect(ids.contains('inspection'), isFalse,
          reason: 'inspection centres live in inspection_centers_geo.json');
    });

    test('the stored ids are stable and not localised', () {
      for (final c in PlaceCategory.values) {
        expect(RegExp(r'^[a-z][a-z_]*$').hasMatch(c.id), isTrue, reason: c.id);
        expect(c.label, isNot(equals(c.id)));
      }
    });

    test('a wash is not a garage', () {
      expect(PlaceCategory.carWash.isGarage, isFalse);
      expect(PlaceCategory.garageBody.isGarage, isTrue);
    });
  });

  group('a rating is not a score until three people have given one', () {
    Place withRatings(int count) => Place(
          id: 'p1',
          source: PlaceSource.community,
          category: PlaceCategory.garageMechanical,
          name: 'מוסך כהן ובניו',
          ratingCount: count,
          createdAt: DateTime(2026, 8, 25),
        );

    test('two opinions do not make an average', () {
      // "5.0 ★" from two people reads as a verdict on somebody's business.
      expect(withRatings(2).hasEnoughRatings, isFalse);
      expect(withRatings(3).hasEnoughRatings, isTrue);
    });
  });

  group('finding a place by what people actually type', () {
    test('the name is broken into searchable words', () {
      // Firestore has no substring query. A prefix range on the name finds
      // this from "מוסך"; the token array is what finds it from "כהן".
      final tokens = Place.tokensFor('מוסך כהן ובניו');
      expect(tokens, contains('כהן'));
      expect(tokens, contains('מוסך'));
    });

    test('punctuation is not part of a word', () {
      expect(Place.tokensFor('מוסך "הצפון", חיפה'), contains('הצפון'));
    });

    test('single letters are dropped', () {
      // They match nearly everything and would make the array useless.
      expect(Place.tokensFor('מוסך א כהן'), isNot(contains('א')));
    });

    test('a repeated word is stored once', () {
      expect(Place.tokensFor('מוסך מוסך').length, 1);
    });
  });

  group('nothing can pretend to be on an official register', () {
    test('a place added from the app is community, always', () {
      final repo = File('lib/data/repositories/place_repository.dart')
          .readAsStringSync();
      // No `source` parameter to pass, so there is no call site that could
      // ask for anything else.
      expect(repo, contains('source: PlaceSource.community'));
      expect(repo.contains('required PlaceSource source'), isFalse);
    });

    test('and the rules refuse it too', () {
      final rules = File('firestore.rules').readAsStringSync();
      final block = rules.substring(rules.indexOf('match /places/{placeId}'));
      expect(block, contains("request.resource.data.source == 'community'"));
      expect(block, contains('request.resource.data.ratingCount == 0'));
    });
  });

  group('the rules bound what a client can do to a rating', () {
    // Spark has no Cloud Functions, so the counters are maintained by the
    // client. The rules cannot check the arithmetic; they can stop one write
    // from moving a rating by more than a single review's worth.
    final rules = File('firestore.rules').readAsStringSync();
    final block = rules.substring(rules.indexOf('match /places/{placeId}'));

    test('one update moves the count by at most one', () {
      expect(block, contains(
          'request.resource.data.ratingCount <= resource.data.ratingCount + 1'));
    });

    test('and the sum by at most five, a rating being 1..5', () {
      expect(block, contains(
          'request.resource.data.ratingSum <= resource.data.ratingSum + 5'));
    });

    test('hiding is one-way', () {
      expect(block, contains('request.resource.data.isHidden == true'));
    });

    test('a place with other people\'s reviews on it cannot be deleted', () {
      expect(block, contains('allow delete: if false'));
    });

    test('one review per person, enforced by the document key', () {
      expect(block, contains('match /reviews/{reviewUid}'));
      expect(block, contains('request.auth.uid == reviewUid'));
      expect(block, contains('request.resource.data.rating <= 5'));
    });
  });
}
