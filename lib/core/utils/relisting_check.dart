import '../../data/models/car_model.dart';
import '../../data/models/plate_snapshot_model.dart';

/// One earlier listing of this plate that is worth putting in front of a buyer.
class Relisting {
  const Relisting({required this.snapshot, required this.stillActive});

  final PlateSnapshot snapshot;

  /// Whether the listing that produced this snapshot is still on the market.
  final bool stillActive;
}

/// What this plate's earlier listings say about the one being read.
///
/// The odometer comparison already lives in [OdometerCheck]; this is the other
/// half — **who** listed the car before, **when**, and whether their listing is
/// still up. `plateHistorySnapshot` has carried the raw material since the
/// rollback check was built; nothing was reading it for this.
///
/// ## Two findings, and only two
///
/// **Another live listing for the same plate.** One car cannot honestly be for
/// sale twice at once. Either a stale listing was never taken down, or one of
/// the two is not what it says it is. Both are worth a buyer's attention and
/// the app cannot tell which it is looking at — so it says both listings exist
/// and stops there.
///
/// **A quick relist by a different kind of seller.** A car listed privately in
/// March and by a dealer in April was bought and is being resold. That is
/// completely legal and extremely common, and it is *not* an accusation. It is
/// simply a fact a buyer would want when the price has moved: the same car,
/// weeks ago, at a different number. `_flipWindow` is deliberately short —
/// beyond it the connection stops being informative and starts being noise.
///
/// ## What is deliberately not here
///
/// **VIN matching across plates.** A car re-plated to escape its own history is
/// the strongest fraud signal there is, and this class cannot look for it: the
/// public listing document carries **neither the plate nor the VIN**, on
/// purpose, so a buyer is never handed the identifier that would let them query
/// a stranger's car. Finding it would mean publishing the thing the privacy
/// design exists to withhold. It needs a server that can compare without
/// disclosing, and there is no server on the Spark plan.
///
/// Nothing here concludes anything, in keeping with the rest of the app: a
/// duplicate listing and a forgotten one produce exactly the same record.
class RelistingCheck {
  RelistingCheck._();

  /// How recently a previous listing has to have run for a change of seller to
  /// be worth mentioning.
  static const flipWindow = Duration(days: 90);

  /// Earlier listings of this plate, newest first, excluding this listing
  /// itself. [activeCarIds] are the ones still on the market.
  static List<Relisting> previous({
    required String currentCarId,
    required List<PlateSnapshot> history,
    required Set<String> activeCarIds,
  }) {
    final earlier = history.where((s) => s.carId != currentCarId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return [
      for (final s in earlier)
        Relisting(snapshot: s, stillActive: activeCarIds.contains(s.carId)),
    ];
  }

  /// Every earlier listing of this plate that is still on the market.
  static List<Relisting> concurrent(List<Relisting> previous) =>
      previous.where((r) => r.stillActive).toList();

  /// The most recent earlier listing by a different kind of seller, inside
  /// [flipWindow] — or null.
  ///
  /// [now] is injected so the window is testable without waiting for the
  /// calendar.
  static Relisting? recentSellerChange({
    required List<Relisting> previous,
    required SellerType currentSellerType,
    required DateTime now,
  }) {
    for (final r in previous) {
      if (r.snapshot.sellerType == currentSellerType) continue;
      if (now.difference(r.snapshot.createdAt) > flipWindow) continue;
      return r;
    }
    return null;
  }

  /// Whole shekels, spaced in thousands, for the finding text.
  static String shekels(double price) => price
      .round()
      .toString()
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
}
