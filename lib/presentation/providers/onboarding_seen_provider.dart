import 'package:shared_preferences/shared_preferences.dart';

/// Whether this device has already been through the three opening screens.
///
/// **They used to run on every single launch.** The splash routed anyone
/// without an account to `/onboarding`, and a guest never has an account — so
/// somebody browsing without signing up met the same three slides, then the
/// login screen, then had to tap "גלוש בלי להתחבר", every time they opened the
/// app. Five steps to reach a listing, forever.
///
/// A guest is not a lesser user here: reading the registry for any car is a
/// whole half of the product and needs no account at all. Making that person
/// re-watch the pitch daily treats browsing as a failure to convert.
///
/// Deliberately a plain static rather than a provider: the splash screen reads
/// it once, before the widget tree that would host a provider is doing
/// anything, and a value that is written once per install does not need to be
/// watched.
class OnboardingSeen {
  OnboardingSeen._();

  static const _key = 'onboarding_seen_v1';

  /// The version suffix is not decoration. If the slides are ever rewritten
  /// into something worth showing again, bumping the key shows them once more
  /// to everyone — without that, an install that has seen ANY onboarding would
  /// never see another.
  static Future<bool> get() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_key) ?? false;
    } catch (_) {
      // A failed read must not strand anyone on the splash screen. Showing the
      // slides one extra time is the harmless direction to fail in.
      return false;
    }
  }

  static Future<void> mark() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_key, true);
    } catch (_) {
      // Nothing to do: the cost is seeing the slides again next launch.
    }
  }
}
