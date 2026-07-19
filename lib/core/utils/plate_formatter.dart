/// Israeli license plate formatting.
///
/// The API is queried with digits only ("1234567"). The UI shows dashes:
///  - 7 digits → "123-45-678" style is not standard; Israeli plates use
///    XX-XXX-XX (8 digits) or XXX-XX-XXX (7 digits). We group as:
///    8 digits → "12-345-67", 7 digits → "123-45-67".
class PlateFormatter {
  PlateFormatter._();

  /// Strips everything except digits — use before calling the API.
  static String digitsOnly(String raw) => raw.replaceAll(RegExp(r'\D'), '');

  /// Formats a digits-only plate for display with dashes.
  static String withDashes(String raw) {
    final d = digitsOnly(raw);
    if (d.length == 8) {
      return '${d.substring(0, 2)}-${d.substring(2, 5)}-${d.substring(5)}';
    }
    if (d.length == 7) {
      return '${d.substring(0, 3)}-${d.substring(3, 5)}-${d.substring(5)}';
    }
    // Unknown length — return as-is.
    return d;
  }
}
