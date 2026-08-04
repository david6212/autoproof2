import 'plate_formatter.dart';

/// Input validation helpers.
class Validators {
  Validators._();

  /// Israeli plates are 7 or 8 digits. Returns null if valid, else a Hebrew
  /// error message.
  static String? plate(String raw) {
    final d = PlateFormatter.digitsOnly(raw);
    if (d.isEmpty) return 'יש להזין מספר רישוי';
    if (d.length < 7 || d.length > 8) {
      return 'מספר רישוי חייב להיות 7 או 8 ספרות';
    }
    return null;
  }

  /// Compares the seller's entered km against the official reading from the
  /// last annual test. Returns null when there is nothing to raise.
  ///
  /// Wording rule (BUSINESS_ROADMAP section 10): this states the two numbers
  /// and that they disagree. It does not say the odometer was rolled back —
  /// a meter can be legitimately replaced, and the registry reading can be
  /// out of date. Which is also why the caller warns rather than blocks.
  static String? kmAgainstLastTest({
    required int enteredKm,
    required int? lastTestKm,
  }) {
    if (enteredKm < 0) return 'קילומטראז\' לא תקין';
    if (lastTestKm != null && enteredKm < lastTestKm) {
      return 'הקילומטראז\' שהזנת (${_thousands(enteredKm)} ק"מ) נמוך מהקריאה '
          'הרשומה בטסט האחרון (${_thousands(lastTestKm)} ק"מ).';
    }
    return null;
  }

  /// 143851 → 143,851. Local so validation carries no package dependency.
  static String _thousands(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
}
