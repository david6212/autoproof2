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

  /// Seller's entered KM must be >= the last recorded test KM (anti-fraud).
  /// Returns null if valid, else a Hebrew error message.
  static String? kmAgainstLastTest({
    required int enteredKm,
    required int? lastTestKm,
  }) {
    if (enteredKm < 0) return 'קילומטראז\' לא תקין';
    if (lastTestKm != null && enteredKm < lastTestKm) {
      return '⚠️ הקילומטראז\' שהוזן נמוך מהטסט האחרון ($lastTestKm ק"מ)';
    }
    return null;
  }
}
