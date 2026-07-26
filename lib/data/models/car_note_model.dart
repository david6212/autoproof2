import 'package:cloud_firestore/cloud_firestore.dart';

/// A note left by someone who went to inspect a listing, so future buyers can
/// see what earlier visitors observed. Stored at cars/{carId}/notes/{noteId}.
class CarNote {
  final String id;
  final String authorUid;
  final String authorName;
  final String text;
  final DateTime createdAt;

  const CarNote({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  factory CarNote.fromFirestore(Map<String, dynamic> data, String id) {
    return CarNote(
      id: id,
      authorUid: data['authorUid'] ?? '',
      authorName: (data['authorName'] as String?)?.trim().isNotEmpty == true
          ? data['authorName']
          : 'מבקר',
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'authorUid': authorUid,
        'authorName': authorName,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
