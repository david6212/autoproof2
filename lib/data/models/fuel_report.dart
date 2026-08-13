/// One driver's report of what diesel actually cost them at one station.
///
/// The whole feature exists because Israel publishes no per-station fuel
/// price: 95 octane is price-controlled and identical everywhere, and diesel
/// is *not* controlled, so it genuinely varies — and nobody publishes it. The
/// only way to know is that someone was there and looked at the sign.
///
/// Stored at `fuel_reports/{stationId}/reports/{uid}`: keyed by the reporter,
/// so a second report replaces their first rather than stuffing the ballot.
/// Nothing identifying is kept beyond the uid the rules need.
class FuelReport {
  const FuelReport({
    required this.uid,
    required this.agorot,
    required this.at,
  });

  final String uid;

  /// Price in agorot. An integer on purpose — money in doubles invites
  /// 7.299999999 to appear on screen.
  final int agorot;

  final DateTime at;

  double get shekels => agorot / 100;

  /// The plausible range for a litre of diesel at an Israeli pump. Anything
  /// outside it is a typo (a missing decimal point, or agorot typed as
  /// shekels), not a bargain — the rules enforce the same bounds server-side.
  static const minAgorot = 300; // 3.00 ₪
  static const maxAgorot = 1500; // 15.00 ₪

  static bool isPlausible(int agorot) =>
      agorot >= minAgorot && agorot <= maxAgorot;
}

/// What the crowd currently says about one station.
///
/// Every number this exposes is paired with how old it is and how many people
/// stand behind it. There is deliberately no "the cheapest diesel" anywhere —
/// only "the lowest price reported", with its age. See [FuelPriceTally.headline].
class FuelPriceTally {
  const FuelPriceTally({
    this.reports = const [],
    this.myAgorot,
  });

  /// Newest first.
  final List<FuelReport> reports;

  /// What the current user last reported here, if anything.
  final int? myAgorot;

  /// How long a report still counts toward the headline figure. Diesel moves
  /// with the market rather than daily, but a fortnight-old price is a
  /// historical note, not a reason to drive somewhere.
  static const freshness = Duration(days: 14);

  /// Below this the figure is one person's word. It is still shown — with the
  /// count — but never presented as a settled price.
  static const minReportsForConfidence = 3;

  List<FuelReport> get fresh {
    final cutoff = DateTime.now().subtract(freshness);
    return reports.where((r) => r.at.isAfter(cutoff)).toList();
  }

  bool get hasFresh => fresh.isNotEmpty;
  int get freshCount => fresh.length;
  bool get isConfident => freshCount >= minReportsForConfidence;

  /// The representative price: the **median** of fresh reports, not the mean.
  /// One fat-fingered 14.99 would drag an average across the whole map; the
  /// median just ignores it.
  int? get medianAgorot {
    final f = fresh;
    if (f.isEmpty) return null;
    final sorted = [for (final r in f) r.agorot]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }

  double? get medianShekels {
    final a = medianAgorot;
    return a == null ? null : a / 100;
  }

  DateTime? get newestAt => reports.isEmpty ? null : reports.first.at;

  /// Age of the newest report in plain Hebrew — mirrors the wording already
  /// used for the seller-encounter tally.
  String? get ageLabel {
    final t = newestAt;
    if (t == null) return null;
    final d = DateTime.now().difference(t);
    if (d.inHours < 1) return 'לפני פחות משעה';
    if (d.inHours < 24) return 'לפני ${d.inHours} שעות';
    if (d.inDays == 1) return 'אתמול';
    if (d.inDays < 30) return 'לפני ${d.inDays} ימים';
    return 'לפני ${(d.inDays / 30).floor()} חודשים';
  }

  /// The single line the card shows. States the source and the age every time,
  /// because a price with neither reads as a fact the app is vouching for.
  ///
  /// Returns null when there is nothing fresh to say — the caller then invites
  /// a report instead of showing a stale number as though it were current.
  String? get headline {
    final s = medianShekels;
    if (s == null) return null;
    final n = freshCount;
    final who = n == 1 ? 'דיווח אחד' : '$n דיווחים';
    return '${s.toStringAsFixed(2)} ₪ לליטר · $who · ${ageLabel ?? ''}'.trim();
  }
}
