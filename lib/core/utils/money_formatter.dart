import 'package:intl/intl.dart';

/// The one place the app turns a shekel amount into text.
///
/// Until 24/09/2026 there were twenty-five of them. The marketplace side wrote
/// `₪132,000` and the garage side wrote `1,200 ₪` — thirteen sites against
/// twelve — so a seller who listed a car and then logged an expense saw both
/// forms in one session, and one screen (the expense delete dialog) dropped
/// the thousands separator altogether while the row behind it kept it.
///
/// **House rule: the number first, then the sign — `98,000 ₪`.**
/// It is the form that survives an RTL line without bidi isolation marks:
/// `₪` is a neutral character, so a prefixed sign gets pulled around by
/// whatever follows it, and `ב-₪1,200` reads worst of all. Only one string in
/// the app ever isolated its price by hand; the rest trusted the renderer.
///
/// `wording_conventions_test` pins this: no Dart file outside this one may
/// write a `₪` immediately before a number.
class MoneyFormatter {
  MoneyFormatter._();

  static final NumberFormat _thousands = NumberFormat('#,###', 'en');

  /// `98000` → `98,000 ₪`.
  static String format(num shekels) => '${thousands(shekels)} ₪';

  /// `98000` → `98,000`, for the few places that need the number without the
  /// sign (a range whose sign is printed once, a text field's suffix).
  static String thousands(num value) => _thousands.format(value);

  /// A per-litre fuel price: two decimals, then the sign and the unit.
  /// `7.19` → `7.19 ₪ לליטר`.
  static String perLitre(num shekels) =>
      '${shekels.toStringAsFixed(2)} ₪ לליטר';
}
