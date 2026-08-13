/// Who operates BonnetCheck, and how to reach them.
///
/// Every legal document reads its identifying details from here, so the
/// operator's details live in exactly one place.
///
/// [operatorName] and [contactEmail] are DELIBERATELY EMPTY. A policy that
/// names an invented entity, or points at a mailbox nobody reads, is worse
/// than no policy at all — so while either is blank the legal screens show an
/// honest "not published yet" notice instead of the documents. Fill both in
/// and the whole section goes live; nothing else needs changing.
class LegalInfo {
  LegalInfo._();

  /// The full name of the person or company operating BonnetCheck, exactly as it
  /// should appear in "מופעל על ידי ___".
  static const operatorName = '';

  /// Address for enquiries, data-deletion requests, content removal and
  /// complaints. Must be a mailbox that is actually monitored.
  static const contactEmail = '';

  /// Optional. A private individual is under no obligation to publish a home
  /// address — the Privacy Protection Law requires it in the *registration*
  /// with the Registrar, not on the site. Leave empty unless a business
  /// address exists.
  static const operatorAddress = '';

  /// Optional. Company / עוסק number, shown only when set.
  static const registrationNumber = '';

  /// Shown at the head of every document.
  static const lastUpdated = 'אוגוסט 2026';

  /// Whether the documents may be shown at all.
  static bool get isPublished =>
      operatorName.trim().isNotEmpty && contactEmail.trim().isNotEmpty;

  /// "מופעל על ידי X (מס' 123), כתובת" — skips the parts that are not set.
  static String get operatorLine {
    final parts = <String>[operatorName];
    if (registrationNumber.trim().isNotEmpty) {
      parts.add('(מס\' $registrationNumber)');
    }
    if (operatorAddress.trim().isNotEmpty) parts.add('· $operatorAddress');
    return parts.join(' ');
  }
}
