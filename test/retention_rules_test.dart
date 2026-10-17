import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/data/repositories/car_repository.dart';

/// SEC-25: the rules refuse a listing older than 730 days to everyone but its
/// seller, and a list query whose results they cannot prove readable is
/// refused WHOLE. So the feed's own bound must sit inside the rules' — if it
/// ever reached past it, the whole feed would go dark, not just the old cars.
/// The behaviour is executed in test/rules/listing_retention.mjs.
void main() {
  final rules = File('firestore.rules').readAsStringSync();

  test('the rules hold the listing to the same 730 days the app promises', () {
    expect(CarRepository.retention.inDays, 730);
    expect(rules, contains(
        "resource.data.createdAt > request.time - duration.value(730, 'd')"));
  });

  test('the feed asks for a window strictly inside it', () {
    expect(CarRepository.feedQueryRetention < CarRepository.retention, isTrue);
    // A few days of margin for a phone clock, not weeks of hidden listings.
    expect(CarRepository.retention - CarRepository.feedQueryRetention,
        lessThanOrEqualTo(const Duration(days: 7)));
  });

  test('and the index that query needs is declared', () {
    final idx = jsonDecode(File('firestore.indexes.json').readAsStringSync())
        as Map<String, dynamic>;
    final composite = (idx['indexes'] as List).cast<Map<String, dynamic>>();
    expect(
      composite.any((i) =>
          i['collectionGroup'] == 'cars' &&
          (i['fields'] as List).map((f) => f['fieldPath']).join(',') ==
              'status,createdAt'),
      isTrue,
    );
  });

  test('a listing cannot be dated so it never expires', () {
    expect(rules, contains(
        "request.resource.data.createdAt < request.time + duration.value(1, 'd')"));
  });
}
