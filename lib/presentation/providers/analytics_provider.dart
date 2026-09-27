import 'package:flutter/widgets.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics_consent_provider.dart';

/// Shared FirebaseAnalytics instance.
final analyticsProvider = Provider<FirebaseAnalytics>((ref) {
  return FirebaseAnalytics.instance;
});

/// Navigator observer that auto-logs a `screen_view` for every pushed route
/// (car detail, vehicle history, login, chat, match, ...). Wired into GoRouter.
///
/// Returns a **plain `NavigatorObserver`** — one that does nothing — until the
/// reader has agreed. This is the observer that used to fire `screen_view` for
/// `/splash` before anything had been asked or shown, which is what an
/// ePrivacy complaint is made of.
final analyticsObserverProvider = Provider<NavigatorObserver>((ref) {
  if (!ref.watch(analyticsAllowedProvider)) return NavigatorObserver();
  return FirebaseAnalyticsObserver(analytics: ref.watch(analyticsProvider));
});

/// Thin helper for the handful of custom events we care about during beta.
/// All calls are fire-and-forget — analytics must never block or crash the UI.
class Analytics {
  Analytics(this._fa, {required this.allowed});

  /// Null when measurement is off. **Not just unused — not even constructed**:
  /// reaching `FirebaseAnalytics.instance` initialises the SDK, and a reader
  /// who declined has no business having it started on their device. It also
  /// means a widget test can pump a screen that logs an event without a
  /// Firebase app behind it.
  final FirebaseAnalytics? _fa;

  /// Whether the reader agreed to measurement. Checked at the single choke
  /// point rather than at each call site, so a new event cannot forget.
  final bool allowed;

  Future<void> _log(String name, [Map<String, Object>? params]) async {
    final fa = _fa;
    if (!allowed || fa == null) return;
    try {
      await fa.logEvent(name: name, parameters: params);
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
  final allowed = ref.watch(analyticsAllowedProvider);
  return Analytics(
    allowed ? ref.watch(analyticsProvider) : null,
    allowed: allowed,
  );
});
