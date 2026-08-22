import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the reader has said about analytics.
///
/// Three states, not two. "Has not been asked" is not "said no": the first is
/// why the sheet appears, the second is why it must not appear again.
enum AnalyticsConsent { unasked, granted, declined }

const _key = 'analytics_consent';

/// The stored answer, loaded once at startup.
///
/// Collection is switched OFF in `main()` before Firebase is even asked for an
/// analytics instance, so the default while this loads is "no measurement" —
/// the opposite of the behaviour this replaces, where a `_ga` cookie and two
/// `collect` calls were already gone before the splash screen finished.
class AnalyticsConsentController extends AsyncNotifier<AnalyticsConsent> {
  @override
  Future<AnalyticsConsent> build() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    final value = switch (stored) {
      'granted' => AnalyticsConsent.granted,
      'declined' => AnalyticsConsent.declined,
      _ => AnalyticsConsent.unasked,
    };
    await _apply(value);
    return value;
  }

  Future<void> set(AnalyticsConsent value) async {
    state = AsyncData(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value.name);
    await _apply(value);
  }

  /// Turning it off is not cosmetic: it stops the SDK collecting, which is
  /// what "withdraw consent" has to mean.
  Future<void> _apply(AnalyticsConsent value) async {
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
        value == AnalyticsConsent.granted,
      );
    } catch (_) {
      // A measurement toggle must never take the app down with it.
    }
  }
}

final analyticsConsentProvider =
    AsyncNotifierProvider<AnalyticsConsentController, AnalyticsConsent>(
  AnalyticsConsentController.new,
);

/// Whether measurement may run right now.
///
/// Anything unresolved counts as "no". A provider that is still loading, or
/// that failed, must not be a reason to start measuring.
final analyticsAllowedProvider = Provider<bool>((ref) {
  return ref.watch(analyticsConsentProvider).valueOrNull ==
      AnalyticsConsent.granted;
});
