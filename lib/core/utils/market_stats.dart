import '../../data/models/car_model.dart';

/// What comparable listings say about a price, and about how long cars like
/// this sit on the market.
///
/// Computed on the device from our own listings. That is not a compromise —
/// it is the only version of this we can honestly ship. A published Israeli
/// price guide (מחירון) is licensed data we do not have the right to
/// redistribute, and inventing our own valuation would be exactly the claim
/// about a specific car that the app refuses to make. "23 similar listings ask
/// between X and Y" is a fact about the market, not a valuation.
class MarketStats {
  /// Below this the numbers are noise dressed as insight. Four listings can
  /// put a car "above the market" because one of them was a bargain, and a
  /// misleading number is worse than a missing one — so under the floor,
  /// nothing renders at all.
  static const minSample = 8;

  /// A model year either side counts as comparable. Buyers shop that way, and
  /// a strict year match would almost never clear [minSample].
  static const yearWindow = 1;

  final int sampleSize;
  final double p25;
  final double p50;
  final double p75;
  final double avgDaysOnMarket;

  const MarketStats({
    required this.sampleSize,
    required this.p25,
    required this.p50,
    required this.p75,
    required this.avgDaysOnMarket,
  });

  /// Where a price sits in the band: below, inside, or above.
  PriceStanding standingOf(double price) {
    if (price < p25) return PriceStanding.below;
    if (price > p75) return PriceStanding.above;
    return PriceStanding.within;
  }

  /// 0 at the 25th percentile, 1 at the 75th, clamped — the marker position on
  /// the band.
  double positionOf(double price) {
    if (p75 <= p25) return 0.5;
    return ((price - p25) / (p75 - p25)).clamp(0.0, 1.0);
  }

  /// Stats for cars comparable to [subject], or null when there are too few.
  ///
  /// [subject] is excluded from its own sample: a listing should not help
  /// decide whether it is itself normally priced.
  static MarketStats? forCar(CarModel subject, List<CarModel> all) {
    final peers = comparablesTo(subject, all);
    if (peers.length < minSample) return null;

    final prices = [for (final c in peers) c.price]..sort();
    final now = DateTime.now();
    final days = [
      for (final c in peers) now.difference(c.createdAt).inDays,
    ];

    return MarketStats(
      sampleSize: peers.length,
      p25: _percentile(prices, 0.25),
      p50: _percentile(prices, 0.50),
      p75: _percentile(prices, 0.75),
      avgDaysOnMarket: days.reduce((a, b) => a + b) / days.length,
    );
  }

  /// Listings of the same model within the year window, excluding [subject].
  static List<CarModel> comparablesTo(CarModel subject, List<CarModel> all) {
    final make = _norm(subject.make);
    final model = _norm(subject.model);

    return [
      for (final c in all)
        if (c.id != subject.id &&
            c.status != CarStatus.removed &&
            _norm(c.make) == make &&
            _norm(c.model) == model &&
            (c.year - subject.year).abs() <= yearWindow &&
            c.price > 0)
          c,
    ];
  }

  /// Nearest-rank percentile on an already-sorted list.
  static double _percentile(List<double> sorted, double fraction) {
    if (sorted.isEmpty) return 0;
    final index = (sorted.length * fraction).floor();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  /// Registry text arrives with stray spacing and case; two listings of one
  /// model must not miss each other over a double space.
  static String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// How long a listing has been up.
  static int daysOnMarket(CarModel car) =>
      DateTime.now().difference(car.createdAt).inDays;
}

enum PriceStanding { below, within, above }

extension PriceStandingX on PriceStanding {
  /// Neutral by design. "מתחת לטווח" is a fact about the asking price; "a
  /// bargain" would be a claim about the car, and a cheap car is often cheap
  /// for a reason the listing does not mention.
  String get label => switch (this) {
        PriceStanding.below => 'מתחת לטווח השוק',
        PriceStanding.within => 'בטווח השוק',
        PriceStanding.above => 'מעל טווח השוק',
      };
}
