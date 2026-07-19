/// Formats dates coming from data.gov.il.
///
/// The registry returns dates as either "YYYY-MM-DD" (current) or "YYYYMMDD"
/// (legacy). Both are handled and rendered as "DD/MM/YYYY".
class DateFormatter {
  DateFormatter._();

  /// Parses a gov date string into a DateTime, or null if unparseable.
  static DateTime? parseGov(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;

    // "YYYY-MM-DD" (may include a time component).
    if (s.contains('-')) {
      return DateTime.tryParse(s);
    }

    // "YYYYMMDD"
    if (s.length == 8 && int.tryParse(s) != null) {
      final y = int.parse(s.substring(0, 4));
      final m = int.parse(s.substring(4, 6));
      final d = int.parse(s.substring(6, 8));
      try {
        return DateTime(y, m, d);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Renders a gov date string as "DD/MM/YYYY", or "—" if unavailable.
  static String fromGov(dynamic raw) {
    final date = parseGov(raw);
    if (date == null) return '—';
    return format(date);
  }

  static String format(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }
}
