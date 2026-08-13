import 'package:flutter_test/flutter_test.dart';

import 'package:otov/data/models/fuel_report.dart';

/// The tally is the only place the app states a fuel price, and it is stating
/// something nobody verified. These tests pin the three rules that keep that
/// honest: a stale price never speaks as a current one, one bad number cannot
/// move the figure, and a price is never shown without its age and its count.
void main() {
  FuelReport at(Duration ago, int agorot, [String uid = 'u']) => FuelReport(
        uid: uid,
        agorot: agorot,
        at: DateTime.now().subtract(ago),
      );

  group('plausibility', () {
    test('rejects the two typos that actually happen', () {
      // A missing decimal point, and agorot typed as if they were shekels.
      expect(FuelReport.isPlausible(729), isTrue); // 7.29 ₪
      expect(FuelReport.isPlausible(72900), isFalse); // 729 ₪
      expect(FuelReport.isPlausible(7), isFalse); // 0.07 ₪
    });

    test('the bounds match what the Firestore rules enforce', () {
      // If these drift apart, the client accepts a value the server rejects
      // and the user sees a save that silently fails.
      expect(FuelReport.minAgorot, 300);
      expect(FuelReport.maxAgorot, 1500);
    });
  });

  group('freshness', () {
    test('a report older than the window does not count', () {
      final t = FuelPriceTally(reports: [at(const Duration(days: 20), 700)]);
      expect(t.hasFresh, isFalse);
      expect(t.medianAgorot, isNull);
      // No headline at all — the card asks for a report instead of showing a
      // three-week-old number as though it were today's.
      expect(t.headline, isNull);
      // The age is still available, so the UI can say why it is silent.
      expect(t.ageLabel, isNotNull);
    });

    test('a report inside the window counts', () {
      final t = FuelPriceTally(reports: [at(const Duration(days: 3), 700)]);
      expect(t.hasFresh, isTrue);
      expect(t.medianShekels, 7.0);
    });

    test('stale reports are excluded from the median, not averaged in', () {
      final t = FuelPriceTally(reports: [
        at(const Duration(days: 1), 700),
        at(const Duration(days: 2), 710, 'b'),
        at(const Duration(days: 40), 300, 'c'), // ancient and cheap
      ]);
      expect(t.freshCount, 2);
      expect(t.medianAgorot, 705);
    });
  });

  group('median, not mean', () {
    test('one fat-fingered price cannot drag the figure', () {
      final t = FuelPriceTally(reports: [
        at(const Duration(hours: 1), 700),
        at(const Duration(hours: 2), 705, 'b'),
        at(const Duration(hours: 3), 710, 'c'),
        at(const Duration(hours: 4), 1499, 'd'), // in range, still nonsense
      ]);
      // Mean would be 903.5 — over 9 ₪ a litre, and wrong for every driver.
      // Median of four is the midpoint of the middle two: (705+710)/2 = 707.5.
      expect(t.medianAgorot, 708);
    });

    test('an even number of reports takes the midpoint', () {
      final t = FuelPriceTally(reports: [
        at(const Duration(hours: 1), 700),
        at(const Duration(hours: 2), 711, 'b'),
      ]);
      expect(t.medianAgorot, 706); // (700+711)/2 rounded
    });
  });

  group('confidence', () {
    test('a single report is shown but not treated as settled', () {
      final t = FuelPriceTally(reports: [at(const Duration(hours: 2), 690)]);
      expect(t.medianShekels, 6.9);
      expect(t.isConfident, isFalse);
    });

    test('three reports clear the bar', () {
      final t = FuelPriceTally(reports: [
        at(const Duration(hours: 1), 690),
        at(const Duration(hours: 2), 695, 'b'),
        at(const Duration(hours: 3), 700, 'c'),
      ]);
      expect(t.isConfident, isTrue);
    });
  });

  group('the headline never states a bare price', () {
    test('it always carries the count and the age', () {
      final t = FuelPriceTally(reports: [
        at(const Duration(hours: 2), 729),
        at(const Duration(hours: 5), 735, 'b'),
      ]);
      final h = t.headline!;
      expect(h, contains('7.32'));
      expect(h, contains('2 דיווחים'));
      expect(h, contains('לפני'));
      // The words the claims audit forbids for anything the app did not check.
      expect(h, isNot(contains('מאומת')));
      expect(h, isNot(contains('הזול ביותר')));
    });

    test('one report reads as one report, not as "1 דיווחים"', () {
      final t = FuelPriceTally(reports: [at(const Duration(hours: 2), 729)]);
      expect(t.headline, contains('דיווח אחד'));
    });
  });
}
