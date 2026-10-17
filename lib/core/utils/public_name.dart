/// "מיכל ש." — the most a public document may say about the person who wrote it.
///
/// A note on somebody's listing and a review of a named garage are both
/// readable by anyone, without an account. Until 10/2026 the screen showed the
/// short form while the document stored the Google display name in full —
/// masking on screen while shipping the value in the document is decoration,
/// the same mistake the plate once made (SEC-18, SEC-19).
///
/// So the writer stores this, the rules refuse anything longer
/// ([publicNamePattern]), and the reader passes legacy documents through it
/// too, so a full name written before the fix still renders shortened.
String publicName(String raw) {
  final parts = raw.trim().split(RegExp(r'\s+'))..removeWhere((p) => p.isEmpty);
  if (parts.isEmpty) return fallbackPublicName;
  // Runes, not code units: an initial is one character, and half a surrogate
  // pair is not one.
  final first = String.fromCharCodes(parts.first.runes.take(maxFirstNameLength));
  if (parts.length == 1) return first;
  return '$first ${String.fromCharCode(parts[1].runes.first)}.';
}

/// What a writer without a usable name is called.
const fallbackPublicName = 'מבקר';

/// A first name is cut here, so the stored value always fits the rule.
const maxFirstNameLength = 30;

/// The shape `firestore.rules` accepts for a public `authorName`: one word, and
/// at most an initial after it. Kept here so the Dart test can pin the two
/// halves to each other.
const publicNamePattern = '[^ ]{1,30}( [^ ][.])?';
