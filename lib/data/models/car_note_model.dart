import 'package:cloud_firestore/cloud_firestore.dart';

/// A fixed observation a visitor can report about a viewing.
///
/// Free typing was removed deliberately: an open box invites accusations about
/// a named seller ("he lied", "he hid an accident"), which is where almost all
/// of the defamation exposure lived. A closed list can only describe the
/// visit, and every option below is a neutral, checkable fact.
enum NoteTag {
  matchedPhotos,
  priceChanged,
  meetingCancelled,
  undisclosedFaults,
  testDrive,
  sellerOnTime,
  dealFellThrough,
}

extension NoteTagX on NoteTag {
  /// Value stored in Firestore — stable, never localise this.
  String get id => switch (this) {
        NoteTag.matchedPhotos => 'matched_photos',
        NoteTag.priceChanged => 'price_changed',
        NoteTag.meetingCancelled => 'meeting_cancelled',
        NoteTag.undisclosedFaults => 'undisclosed_faults',
        NoteTag.testDrive => 'test_drive',
        NoteTag.sellerOnTime => 'seller_on_time',
        NoteTag.dealFellThrough => 'deal_fell_through',
      };

  String get label => switch (this) {
        NoteTag.matchedPhotos => 'הרכב תאם את התמונות',
        NoteTag.priceChanged => 'המחיר השתנה בפגישה',
        NoteTag.meetingCancelled => 'הפגישה בוטלה',
        NoteTag.undisclosedFaults => 'נמצאו ליקויים שלא צוינו',
        NoteTag.testDrive => 'בוצעה נסיעת מבחן',
        NoteTag.sellerOnTime => 'המוכר הגיע בזמן',
        NoteTag.dealFellThrough => 'העסקה לא יצאה לפועל',
      };

  /// Positive observations render green, cautionary ones amber. Nothing here
  /// is an accusation, so there is no "red".
  bool get isPositive => switch (this) {
        NoteTag.matchedPhotos || NoteTag.testDrive || NoteTag.sellerOnTime =>
          true,
        _ => false,
      };

  static NoteTag? fromId(String id) {
    for (final t in NoteTag.values) {
      if (t.id == id) return t;
    }
    return null;
  }
}

/// A note left by someone who went to inspect a listing, so future buyers can
/// see what earlier visitors observed. Stored at cars/{carId}/notes/{noteId}.
class CarNote {
  final String id;
  final String authorUid;
  final String authorName;
  final DateTime createdAt;

  /// The observations ticked from the fixed list. This is the only part ever
  /// shown to other users.
  final List<NoteTag> tags;

  /// Optional free text under "אחר". Stored for review but NEVER rendered
  /// until a moderator clears it — see [approved].
  final String otherText;

  /// Whether [otherText] has been cleared for display. Nothing in the client
  /// can set this; it stays false until reviewed out of band.
  final bool approved;

  /// Optional community flag on the seller's REAL type: '' (none), 'agent', or
  /// 'dealer' — a visitor reporting how a "private" seller actually operated.
  final String sellerFlag;

  const CarNote({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.createdAt,
    this.tags = const [],
    this.otherText = '',
    this.approved = false,
    this.sellerFlag = '',
  });

  /// True when there is nothing displayable — an "other"-only note awaiting
  /// review renders as pending rather than as content.
  bool get hasVisibleContent => tags.isNotEmpty;

  bool get hasPendingText => otherText.trim().isNotEmpty && !approved;

  /// Human label for the flag, or null when there's no flag. Phrased as how the
  /// seller operated, not as what they are.
  String? get flagLabel => switch (sellerFlag) {
        'agent' => 'המוכר פעל כסוכן',
        'dealer' => 'המוכר פעל כסוחר / מגרש',
        _ => null,
      };

  factory CarNote.fromFirestore(Map<String, dynamic> data, String id) {
    final rawTags = (data['tags'] as List?) ?? const [];
    return CarNote(
      id: id,
      authorUid: data['authorUid'] ?? '',
      authorName: (data['authorName'] as String?)?.trim().isNotEmpty == true
          ? data['authorName']
          : 'מבקר',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tags: [
        for (final t in rawTags)
          if (NoteTagX.fromId('$t') case final tag?) tag,
      ],
      otherText: data['otherText'] ?? '',
      approved: data['approved'] ?? false,
      sellerFlag: data['sellerFlag'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'authorUid': authorUid,
        'authorName': authorName,
        'createdAt': FieldValue.serverTimestamp(),
        'tags': [for (final t in tags) t.id],
        'otherText': otherText,
        'approved': false,
        'sellerFlag': sellerFlag,
      };
}
