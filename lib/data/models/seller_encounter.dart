import 'car_model.dart';

/// Aggregated result of buyers reporting WHO they actually met at the deal —
/// private owner / agent / dealer. Each buyer contributes one report (the doc
/// is keyed by their uid), so this is a crowd tally rather than a raw list.
/// The whole point: the trust rating is truly in the buyers' hands.
class EncounterTally {
  final int privateCount;
  final int agentCount;
  final int dealerCount;

  /// What the CURRENT user reported for this car, or null if they haven't.
  final SellerType? myReport;

  const EncounterTally({
    this.privateCount = 0,
    this.agentCount = 0,
    this.dealerCount = 0,
    this.myReport,
  });

  int get total => privateCount + agentCount + dealerCount;

  int countFor(SellerType type) => switch (type) {
        SellerType.private => privateCount,
        SellerType.agent => agentCount,
        SellerType.dealer => dealerCount,
      };

  /// The most-reported type, or null when there are no reports. Ties resolve
  /// toward the "less flattering" end (dealer > agent > private) so a contested
  /// listing never looks safer than it is.
  SellerType? get majority {
    if (total == 0) return null;
    var best = SellerType.private;
    for (final t in [SellerType.agent, SellerType.dealer]) {
      if (countFor(t) >= countFor(best)) best = t;
    }
    return best;
  }

  /// True when the crowd clearly points at a different type than [declared] —
  /// at least two reports for the majority, and it outweighs the declared type.
  bool disagreesWith(SellerType declared) {
    final m = majority;
    if (m == null || m == declared) return false;
    return countFor(m) >= 2 && countFor(m) > countFor(declared);
  }
}
