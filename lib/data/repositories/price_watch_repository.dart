import 'package:shared_preferences/shared_preferences.dart';

/// Remembers what a saved listing cost when it was saved, so a drop can be
/// spotted the next time the list is opened.
///
/// Deliberately on the device and not in Firestore. Noticing a price change
/// while the app is closed needs a server, which the free plan does not
/// include — so rather than build a shared collection that only ever gets read
/// by its own writer, the price rides along with the save. It costs nothing,
/// it leaks nothing, and it is honest about being a "since you last looked"
/// comparison rather than a live alert.
///
/// The trade-off, stated plainly: this is per device. Saving on a phone and
/// opening on a laptop starts the comparison over.
class PriceWatchRepository {
  PriceWatchRepository({SharedPreferences? prefs}) : _injected = prefs;

  final SharedPreferences? _injected;
  SharedPreferences? _cached;

  static const _prefix = 'saved_price_';

  Future<SharedPreferences> get _prefs async =>
      _injected ?? (_cached ??= await SharedPreferences.getInstance());

  String _key(String carId) => '$_prefix$carId';

  /// Records the price at save time. Never overwrites: the whole point is to
  /// compare against what the price was when the buyer first took an interest.
  Future<void> remember(String carId, double price) async {
    final prefs = await _prefs;
    if (prefs.containsKey(_key(carId))) return;
    await prefs.setDouble(_key(carId), price);
  }

  /// Forgets a listing — called when it is unsaved, so re-saving later starts
  /// a fresh comparison rather than resurrecting a year-old price.
  Future<void> forget(String carId) async {
    final prefs = await _prefs;
    await prefs.remove(_key(carId));
  }

  /// Drops for a whole list, in one pass — the saved screen renders at once.
  Future<Map<String, double>> dropsFor(Map<String, double> currentPrices) async {
    final prefs = await _prefs;
    final drops = <String, double>{};
    currentPrices.forEach((carId, price) {
      final before = prefs.getDouble(_key(carId));
      if (before != null && before > price) drops[carId] = before - price;
    });
    return drops;
  }
}
