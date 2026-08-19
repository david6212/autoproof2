import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The alerts this app is allowed to raise.
///
/// Four, and the list is short on purpose. The test each one had to pass:
/// **if we said nothing, would the reader lose something real?** A test that
/// lapses costs a fine and an uninsurable car. An open recall is a free repair
/// nobody told them about. A saved listing dropping in price is money. A reply
/// from a seller is the conversation they started.
///
/// Everything that failed that test is absent, and its absence is the feature:
/// no "new cars in your area", no "somebody is looking at a car you saved", no
/// "you haven't opened the app in a week". Those exist to move the reader, not
/// to inform them, and this app does not get to do that.
enum AlertKind {
  /// Test, insurance, timing belt, service interval — the owner's own dates.
  reminders,

  /// A manufacturer recall the registry lists as still open.
  recalls,

  /// A listing the reader saved now costs less than when they saved it.
  priceDrops,

  /// A seller answered a message the reader sent.
  chatReplies,
}

extension AlertKindX on AlertKind {
  String get label => switch (this) {
        AlertKind.reminders => 'תזכורות לרכב שלי',
        AlertKind.recalls => 'קריאות שירות פתוחות',
        AlertKind.priceDrops => 'ירידת מחיר ברכב שמור',
        AlertKind.chatReplies => 'תשובות מהמוכר',
      };

  /// What the reader gives up by switching it off. Stated plainly, because a
  /// toggle whose consequence is hidden is not really a choice.
  String get cost => switch (this) {
        AlertKind.reminders =>
          'טסט, ביטוח ורצועת תזמון — לא נזכיר לכם שהתאריך מתקרב.',
        AlertKind.recalls =>
          'תיקון שהיצרן מבצע ללא עלות — לא נספר לכם שהוא פתוח.',
        AlertKind.priceDrops =>
          'רכב ששמרתם והמחיר שלו ירד — לא נסמן לכם את ההפרש.',
        AlertKind.chatReplies =>
          'מוכר שהשיב להודעה שלכם — לא יופיע כאן עד שתיכנסו לצ׳אט.',
      };

  String get _prefsKey => 'alert.$name';
}

/// Which alerts are switched on, remembered between launches.
///
/// All on by default: someone who has not expressed a preference is better
/// served by being told their test expires than by silence. Off is a decision
/// the reader makes, and it sticks.
class AlertPrefsNotifier extends Notifier<Set<AlertKind>> {
  @override
  Set<AlertKind> build() {
    _restore();
    return AlertKind.values.toSet();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final on = <AlertKind>{
        for (final k in AlertKind.values)
          if (prefs.getBool(k._prefsKey) ?? true) k,
      };
      if (on.length != state.length) state = on;
    } catch (_) {
      // No storage — everything stays on, which is the safe direction.
    }
  }

  bool isOn(AlertKind kind) => state.contains(kind);

  Future<void> set(AlertKind kind, bool on) async {
    // Spelled out rather than a conditional with a cascade. Written as
    // `on ? {...state, kind} : {...state}..remove(kind)` the cascade binds to
    // the whole conditional, so switching an alert ON removed it as well —
    // every toggle was one-way and silently so.
    final next = {...state};
    if (on) {
      next.add(kind);
    } else {
      next.remove(kind);
    }
    state = next;
    try {
      await (await SharedPreferences.getInstance())
          .setBool(kind._prefsKey, on);
    } catch (_) {
      // The choice still applies to this session.
    }
  }
}

final alertPrefsProvider =
    NotifierProvider<AlertPrefsNotifier, Set<AlertKind>>(
  AlertPrefsNotifier.new,
);

/// Convenience for the four call sites that gate a single strip or badge.
final alertEnabledProvider = Provider.family<bool, AlertKind>(
  (ref, kind) => ref.watch(alertPrefsProvider).contains(kind),
);
