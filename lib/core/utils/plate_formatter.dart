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

  /// The same plate with every digit replaced by an asterisk.
  ///
  /// Sellers routinely tape over the plate before photographing a car, and an
  /// app that prints the number underneath the photo has taken that decision
  /// away from them. The registry data stays — that is what the listing is
  /// for — but the number that identifies the car and its owner to any
  /// stranger does not.
  ///
  /// The dash grouping is kept so it still reads as a plate rather than as a
  /// row of stars, and so the layout does not jump when an owner sees their
  /// own number in full.
  static String masked(String raw) =>
      withDashes(raw).replaceAll(RegExp(r'\d'), '*');
}
