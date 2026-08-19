import '../../data/models/plate_snapshot_model.dart';

/// Whether a listing's odometer disagrees with a reading recorded earlier.
///
/// The comparison is trivial; keeping it in one place is not. The rule is now
/// read by two screens — the evidence card on the listing and the findings
/// block at the top of the page — and two copies of "is this number lower
/// than that one" would eventually disagree with each other, which on this
/// particular question means the app contradicting itself in public.
///
/// Nothing here concludes anything. A mismatch is a mismatch: a seller who
/// typed a digit wrong and a seller who wound the clock back produce exactly
/// the same record, and the app has no way to tell them apart.
class OdometerCheck {
  const OdometerCheck._();

  /// The official reading worth comparing against, or null when the registry
  /// has none. Zero counts as "no reading" — it is what the dataset returns
  /// for a car that has never been tested.
  static int? officialReading(int? lastTestKm) =>
      (lastTestKm != null && lastTestKm > 0) ? lastTestKm : null;

  /// The listing reads lower than the last official test.
  static bool belowOfficial({required int? officialKm, required int currentKm}) =>
      officialKm != null && officialKm > currentKm;

  /// The listing reads lower than one of this plate's earlier listings.
  static bool belowPastListings({
    required List<PlateSnapshot> previous,
    required int currentKm,
  }) =>
      previous.any((s) => s.km > currentKm);

  /// The highest earlier listing that reads above the current one, or null.
  /// The findings block quotes its numbers, so it needs the snapshot itself
  /// rather than only the fact that one exists.
  static PlateSnapshot? highestAbove({
    required List<PlateSnapshot> previous,
    required int currentKm,
  }) {
    PlateSnapshot? highest;
    for (final s in previous) {
      if (s.km > currentKm && (highest == null || s.km > highest.km)) {
        highest = s;
      }
    }
    return highest;
  }
}
