import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared FirebaseAnalytics instance.
final analyticsProvider = Provider<FirebaseAnalytics>((ref) {
  return FirebaseAnalytics.instance;
});

/// Navigator observer that auto-logs a `screen_view` for every pushed route
/// (car detail, vehicle history, login, chat, match, ...). Wired into GoRouter.
final analyticsObserverProvider = Provider<FirebaseAnalyticsObserver>((ref) {
  return FirebaseAnalyticsObserver(analytics: ref.watch(analyticsProvider));
});

/// Thin helper for the handful of custom events we care about during beta.
/// All calls are fire-and-forget — analytics must never block or crash the UI.
class Analytics {
  Analytics(this._fa);
  final FirebaseAnalytics _fa;

  Future<void> _log(String name, [Map<String, Object>? params]) async {
    try {
      await _fa.logEvent(name: name, parameters: params);
    } catch (_) {
      // Never let analytics failures surface to the user.
    }
  }

  /// The differentiating feature — an official gov.il history lookup.
  ///
  /// The plate is deliberately NOT sent. A plate is linkable to its registered
  /// owner, so shipping it to a third-party analytics service would put
  /// personal data there for no product gain — the count alone answers the
  /// only question we ask of it ("is anyone using lookups?").
  Future<void> vehicleLookup() => _log('vehicle_lookup');

  /// A guest hit a feature that needs an account (save / chat / like).
  Future<void> guestPrompt(String action) =>
      _log('guest_prompt', {'action': action});

  /// Phone sign-in finished successfully.
  Future<void> loginCompleted() => _log('login_completed');

  /// A buyer opened a chat with a seller.
  Future<void> chatStarted() => _log('chat_started');
}

final analyticsHelperProvider = Provider<Analytics>((ref) {
  return Analytics(ref.watch(analyticsProvider));
});
