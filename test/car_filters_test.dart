import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/presentation/providers/cars_provider.dart';

/// Price, year and km used to be single-ended: a ceiling, set with a slider.
/// A buyer thinks in ranges — "between 2018 and 2022", "80 to 120 thousand" —
/// and knows their exact number, so both ends are now typed.
///
/// The risk in a two-ended range is that one end silently filters everything
/// out: an unset bound has to mean "no bound", not zero.
void main() {
  group('an untouched filter narrows nothing', () {
    test('the defaults are the sentinels, not zeros', () {
      const f = CarFilters();
      expect(f.minPrice, CarFilters.priceFloor);
      expect(f.maxPrice, CarFilters.priceCap);
      expect(f.minYear, CarFilters.yearFloor);
      expect(f.maxYear, CarFilters.yearCap);
      expect(f.minKm, CarFilters.kmFloor);
      expect(f.maxKm, CarFilters.kmCap);
      expect(f.isDefault, isTrue);
      expect(f.activeCount, 0);
    });

    test('the year ceiling is past anything the registry can return', () {
      // If this ever fell below a real model year, leaving the field blank
      // would quietly hide the newest cars.
      expect(CarFilters.yearCap, greaterThan(DateTime.now().year + 5));
    });
  });

  group('setting one end leaves the other open', () {
    test('a lower bound alone is still one active filter', () {
      const f = CarFilters(minPrice: 60000);
      expect(f.isDefault, isFalse);
      expect(f.maxPrice, CarFilters.priceCap, reason: 'the top stays open');
      expect(f.activeCount, 1);
    });

    test('an upper bound alone is still one active filter', () {
      const f = CarFilters(maxYear: 2020);
      expect(f.isDefault, isFalse);
      expect(f.minYear, CarFilters.yearFloor);
      expect(f.activeCount, 1);
    });
  });

  group('the badge counts filters, not bounds', () {
    test('both ends of one range still count once', () {
      // "price" is one thing the buyer narrowed. Counting it twice would make
      // the badge say 6 for three filters.
      const f = CarFilters(minPrice: 60000, maxPrice: 120000);
      expect(f.activeCount, 1);
    });

    test('three ranges at both ends count three', () {
      const f = CarFilters(
        minPrice: 60000,
        maxPrice: 120000,
        minYear: 2018,
        maxYear: 2022,
        minKm: 10000,
        maxKm: 90000,
      );
      expect(f.activeCount, 3);
    });
  });

  group('copyWith keeps the end it was not given', () {
    test('setting the low end does not reset the high one', () {
      const f = CarFilters(maxPrice: 120000);
      final g = f.copyWith(minPrice: 60000);
      expect(g.minPrice, 60000);
      expect(g.maxPrice, 120000, reason: 'the ceiling survived');
    });

    test('setting the high end does not reset the low one', () {
      const f = CarFilters(minYear: 2018);
      final g = f.copyWith(maxYear: 2022);
      expect(g.minYear, 2018);
      expect(g.maxYear, 2022);
    });
  });
}
