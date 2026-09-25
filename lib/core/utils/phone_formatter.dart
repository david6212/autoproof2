/// Israeli phone numbers, in the form the person who typed them recognises.
///
/// The app stores and sends E.164 (`+972501234567`) because that is what
/// Firebase wants. It used to *show* that string too — the very first sentence
/// a new user read after handing over their number was
/// `שלחנו קוד בן 6 ספרות אל +972501234567`, a number they had never typed and
/// do not read as theirs. This turns it back into `050-1234567`.
class PhoneFormatter {
  PhoneFormatter._();

  /// `+972501234567` → `050-1234567`. Anything it cannot read comes back
  /// unchanged, so a foreign number is shown as it is rather than mangled.
  static String local(String? e164) {
    final raw = (e164 ?? '').trim();
    if (raw.isEmpty) return '';

    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('972')) {
      digits = '0${digits.substring(3)}';
    } else if (!digits.startsWith('0')) {
      return raw;
    }

    // Israeli numbers are 9 or 10 digits with the leading zero, and the
    // subscriber part is always the last seven.
    if (digits.length < 9 || digits.length > 10) return raw;
    final prefix = digits.substring(0, digits.length - 7);
    return '$prefix-${digits.substring(digits.length - 7)}';
  }
}
