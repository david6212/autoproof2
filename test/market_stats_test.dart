import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/core/utils/market_stats.dart';
import 'package:bonnetcheck/data/models/car_model.dart';

/// The price band is the honest version of a valuation: a range of what
/// comparable listings ASK, computed from our own data, with a floor under it
/// so a thin sample never gets dressed up as insight.
void main() {
  CarModel car({
    String id = 'c',
    String make = 'מאזדה',
    String model = 'CX-5',
    int year = 2019,
    double price = 100000,
    int daysAgo = 10,
    CarStatus status = CarStatus.active,
  }) =>
      CarModel(
        id: id,
        plate: '88888888',
        make: make,
        model: model,
        year: year,
        price: price,
        km: 90000,
        hand: 2,
        area: 'תל אביב',
        sellerId: 's1',
        status: status,
        photos: const [],
        reasonForSelling: '',
        createdAt: DateTime.now().subtract(Duration(days: daysAgo)),
      );

  List<CarModel> peers(int n, {double from = 80000, double step = 5000}) => [
        for (var i = 0; i < n; i++)
          car(id: 'p$i', price: from + step * i, daysAgo: 10 + i),
      ];

  group('the sample floor', () {
    test('seven comparable listings are not enough to say anything', () {
      // Four listings can put a car "above the market" because one of them was
      // a bargain. A misleading number is worse than a missing one.
      final subject = car(id: 'subject');
      expect(MarketStats.forCar(subject, peers(7)), isNull);
    });

    test('eight are', () {
      final subject = car(id: 'subject');
      final stats = MarketStats.forCar(subject, peers(8));
      expect(stats, isNotNull);
      expect(stats!.sampleSize, 8);
    });

    test('the car being priced is not part of its own sample', () {
      // Otherwise a listing helps decide whether it is itself normal.
      final subject = car(id: 'subject', price: 999999);
      final stats = MarketStats.forCar(subject, [subject, ...peers(8)]);
      expect(stats!.sampleSize, 8);
      expect(stats.p75, lessThan(999999));
    });
  });

  group('what counts as comparable', () {
    test('a different model does not, however similar the price', () {
      final subject = car(id: 'subject');
      final others = [
        for (var i = 0; i < 10; i++)
          car(id: 'o$i', model: 'CX-30', price: 100000),
      ];
      expect(MarketStats.forCar(subject, others), isNull);
    });

    test('a year either side does', () {
      final subject = car(id: 'subject', year: 2019);
      final mixed = [
        for (var i = 0; i < 4; i++) car(id: 'a$i', year: 2018),
        for (var i = 0; i < 4; i++) car(id: 'b$i', year: 2020),
      ];
      expect(MarketStats.forCar(subject, mixed)!.sampleSize, 8);
    });

    test('two years away does not', () {
      final subject = car(id: 'subject', year: 2019);
      final far = [for (var i = 0; i < 10; i++) car(id: 'f$i', year: 2022)];
      expect(MarketStats.forCar(subject, far), isNull);
    });

    test('spacing and case in the registry text do not split a model', () {
      // "מאזדה  CX-5" and "מאזדה CX-5" are one model to a buyer.
      final subject = car(id: 'subject');
      final sloppy = [
        for (var i = 0; i < 8; i++)
          car(id: 's$i', make: ' מאזדה ', model: 'cx-5  '),
      ];
      expect(MarketStats.forCar(subject, sloppy)!.sampleSize, 8);
    });

    test('a removed listing is not part of the market', () {
      final subject = car(id: 'subject');
      final withRemoved = [
        ...peers(7),
        car(id: 'gone', status: CarStatus.removed),
      ];
      expect(MarketStats.forCar(subject, withRemoved), isNull);
    });
  });

  group('the band', () {
    // Prices 80,000 → 115,000 in 5,000 steps. Nearest-rank: p25 is index 2,
    // p75 is index 6.
    final stats = MarketStats.forCar(car(id: 'subject'), peers(8))!;

    test('brackets the middle half of asking prices', () {
      expect(stats.p25, 90000);
      expect(stats.p75, 110000);
      expect(stats.p50, 100000);
    });

    test('places a price inside, below or above without judging it', () {
      expect(stats.standingOf(100000), PriceStanding.within);
      expect(stats.standingOf(50000), PriceStanding.below);
      expect(stats.standingOf(200000), PriceStanding.above);
    });

    test('the marker never leaves the bar', () {
      expect(stats.positionOf(90000), 0.0);
      expect(stats.positionOf(110000), 1.0);
      expect(stats.positionOf(1), 0.0);
      expect(stats.positionOf(9999999), 1.0);
    });

    test('a market where every car asks the same still renders', () {
      // p75 == p25 would divide by zero; the marker sits in the middle.
      final flat = [
        for (var i = 0; i < 8; i++) car(id: 'f$i', price: 100000),
      ];
      final s = MarketStats.forCar(car(id: 'subject'), flat)!;
      expect(s.p25, s.p75);
      expect(s.positionOf(100000), 0.5);
    });
  });

  group('days on market', () {
    test('counts from when the listing went up', () {
      expect(MarketStats.daysOnMarket(car(daysAgo: 47)), 47);
      expect(MarketStats.daysOnMarket(car(daysAgo: 0)), 0);
    });

    test('the model average comes from the same comparable set', () {
      // peers(8) are 10..17 days old — mean 13.5.
      final stats = MarketStats.forCar(car(id: 'subject'), peers(8))!;
      expect(stats.avgDaysOnMarket, closeTo(13.5, 0.01));
    });
  });
}
