import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A short-lived copy of what the government datasets answered.
///
/// **Why this exists.** data.gov.il asks not to be hammered, and the lists this
/// app reads are large and slow-moving: 1,255 fuel stations, every licensed
/// inspection centre in the country, one refinery price per month. Without a
/// cache the app re-downloaded all of it on every cold start — a cost paid by
/// the user's battery and data, and a way to end up rate-limited or blocked on
/// a dataset the whole product depends on.
///
/// **What is deliberately NOT cached: a plate lookup.** Keeping the registry's
/// answers about cars somebody browsed would leave a list of plates on the
/// device, and the one thing this app has been careful about from the start is
/// not accumulating plates. Those answers stay in memory for the session and
/// are gone when the app closes. The rest of the app's caching lives here.
///
/// Entries are stored as `{"at": epochMillis, "data": ...}`. A stale entry is
/// not deleted on read: [readStale] hands it back when the network fails, so a
/// dead connection shows yesterday's stations rather than an empty map.
class GovCache {
  GovCache({SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;

  static const _prefix = 'gov_cache_';

  /// How long each dataset stays fresh. Chosen from how fast the underlying
  /// thing changes, not from what is convenient: a garage opens or closes over
  /// months, the refinery price changes monthly, and the station list is the
  /// slowest-moving of the three.
  static const fuelStationsTtl = Duration(hours: 24);
  static const inspectionCentersTtl = Duration(days: 7);
  static const refineryPricesTtl = Duration(hours: 12);
  static const garagesTtl = Duration(days: 3);

  Future<SharedPreferences> get _store async =>
      _prefs ?? await SharedPreferences.getInstance();

  /// The cached value if it is still fresh, otherwise null.
  Future<Object?> read(String key, Duration ttl) async {
    final entry = await _entry(key);
    if (entry == null) return null;
    final at = entry['at'];
    if (at is! int) return null;
    final age = DateTime.now().millisecondsSinceEpoch - at;
    // Inclusive, so a zero ttl means "always ask" rather than "fresh for the
    // first millisecond".
    if (age >= ttl.inMilliseconds) return null;
    return entry['data'];
  }

  /// The cached value whatever its age — for when the network has just failed
  /// and stale data is better than none. The caller decides whether to say so.
  Future<Object?> readStale(String key) async {
    final entry = await _entry(key);
    return entry?['data'];
  }

  /// When this key was last written, or null if it never was.
  Future<DateTime?> writtenAt(String key) async {
    final at = (await _entry(key))?['at'];
    return at is int ? DateTime.fromMillisecondsSinceEpoch(at) : null;
  }

  Future<void> write(String key, Object data) async {
    final store = await _store;
    await store.setString(
      _prefix + key,
      jsonEncode({'at': DateTime.now().millisecondsSinceEpoch, 'data': data}),
    );
  }

  /// Drops everything this class wrote. Used by account deletion, so "delete
  /// my data" does not leave the device holding a copy of what was looked up.
  Future<void> clear() async {
    final store = await _store;
    for (final key in store.getKeys().where((k) => k.startsWith(_prefix))) {
      await store.remove(key);
    }
  }

  Future<Map<String, dynamic>?> _entry(String key) async {
    final store = await _store;
    final raw = store.getString(_prefix + key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      // A half-written or outdated shape is not worth a crash on startup.
      return null;
    }
  }
}
