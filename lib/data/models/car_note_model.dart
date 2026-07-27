import 'package:cloud_firestore/cloud_firestore.dart';

/// A note left by someone who went to inspect a listing, so future buyers can
/// see what earlier visitors observed. Stored at cars/{carId}/notes/{noteId}.
class CarNote {
  final String id;
  final String authorUid;
  final String authorName;
  final String text;
  final DateTime createdAt;

  /// Optional community flag on the seller's REAL type: '' (none), 'agent', or
  /// 'dealer' — a visitor reporting that a "private" seller is actually a
  /// broker or a car lot.
  final String sellerFlag;

  const CarNote({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.text,
    required this.createdAt,
    this.sellerFlag = '',
  });

  /// Human label for the flag, or null when there's no flag.
  String? get flagLabel => switch (sellerFlag) {
        'agent' => 'המוכר בעצם סוכן',
        'dealer' => 'המוכר בעצם סוחר / מגרש',
        _ => null,
      };

  factory CarNote.fromFirestore(Map<String, dynamic> data, String id) {
    return CarNote(
      id: id,
      authorUid: data['authorUid'] ?? '',
      authorName: (data['authorName'] as String?)?.trim().isNotEmpty == true
          ? data['authorName']
          : 'מבקר',
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sellerFlag: data['sellerFlag'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'authorUid': authorUid,
        'authorName': authorName,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'sellerFlag': sellerFlag,
      };
}
