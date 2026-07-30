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

  /// When the most recent report came in. A percentage with no date implies
  /// it is current; showing the age lets the reader weigh it.
  final DateTime? lastReportAt;

  const EncounterTally({
    this.privateCount = 0,
    this.agentCount = 0,
    this.dealerCount = 0,
    this.myReport,
    this.lastReportAt,
  });

  /// Short Hebrew age of the newest report, or null if there are none.
  String? get lastUpdatedLabel {
    final t = lastReportAt;
    if (t == null) return null;
    final d = DateTime.now().difference(t);
    if (d.inDays < 1) return 'עודכן היום';
    if (d.inDays == 1) return 'עודכן אתמול';
    if (d.inDays < 30) return 'עודכן לפני ${d.inDays} ימים';
    if (d.inDays < 365) return 'עודכן לפני ${(d.inDays / 30).floor()} חודשים';
    return 'עודכן לפני ${(d.inDays / 365).floor()} שנים';
  }

  int get total => privateCount + agentCount + dealerCount;

  int countFor(SellerType type) => switch (type) {
        SellerType.private => privateCount,
        SellerType.agent => agentCount,
        SellerType.dealer => dealerCount,
      };

  /// Share of reports for [type], 0..1.
  double shareFor(SellerType type) =>
      total == 0 ? 0 : countFor(type) / total;

  /// Rounded percentage for [type] — what the UI actually states, since the
  /// figure is presented as "X% of reporters said…", never as a fact.
  int percentFor(SellerType type) => (shareFor(type) * 100).round();

  /// Fewest reports before a tally is worth showing at all. Below this the UI
  /// says there isn't enough information rather than implying a pattern from
  /// one or two opinions.
  static const minReportsToShow = 3;

  bool get hasEnoughReports => total >= minReportsToShow;

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

  /// True when enough reporters point at a type other than [declared]. Only
  /// gates whether to draw attention — the wording stays statistical, never a
  /// claim about the seller.
  bool disagreesWith(SellerType declared) {
    final m = majority;
    if (m == null || m == declared || !hasEnoughReports) return false;
    return countFor(m) > countFor(declared);
  }
}
