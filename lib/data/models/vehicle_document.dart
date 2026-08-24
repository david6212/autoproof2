enum DocumentType {
  licence, // רישיון רכב
  insurance, // פוליסת ביטוח
  inspectionReport, // דוח בדיקה ממכון
  purchaseContract, // חוזה קנייה
  receipt, // חשבונית / קבלה
  other,
}

extension DocumentTypeX on DocumentType {
  String get label => switch (this) {
        DocumentType.licence => 'רישיון רכב',
        DocumentType.insurance => 'פוליסת ביטוח',
        DocumentType.inspectionReport => 'דוח בדיקה',
        DocumentType.purchaseContract => 'חוזה קנייה',
        DocumentType.receipt => 'חשבונית',
        DocumentType.other => 'מסמך',
      };

  /// Whether this kind of document routinely carries the owner's personal
  /// details — an ID number, a home address, a policy number.
  ///
  /// Used to warn before sharing, not to forbid it. The owner may have a good
  /// reason; they should just know what they are about to publish.
  bool get carriesPersonalData => switch (this) {
        DocumentType.licence => true,
        DocumentType.insurance => true,
        DocumentType.purchaseContract => true,
        DocumentType.inspectionReport => false,
        DocumentType.receipt => false,
        DocumentType.other => false,
      };
}

/// A file the owner attached to their vehicle — a scanned test certificate, an
/// inspection report, an invoice.
///
/// **Private by default.** [isSharedWithBuyers] starts false and only the
/// owner can turn it on, per document. This is not caution for its own sake: a
/// vehicle licence and an insurance policy carry an ID number and a home
/// address, and an app that published those the moment they were uploaded
/// would be leaking its own users' personal data. The owner decides that the
/// inspection report is worth showing and that their purchase contract is not.
///
/// **Where the bytes are.** In Firestore, in a `file/blob` document one level
/// below this record — not in Cloud Storage, which needs a paid plan this
/// project does not have. Two things follow from that, and both are
/// improvements rather than compromises:
///
/// - **Unsharing genuinely revokes.** A Storage download URL carries its own
///   access token and keeps working after the switch is turned off; a
///   Firestore read is evaluated against the rules every time. Once sharing is
///   off, nobody who did not already save the picture can open it again.
/// - **The file is capped at ~900 KB**, because a Firestore document is capped
///   at 1 MiB. `DocumentRedactor` resizes and re-encodes to fit. A multi-page
///   PDF does not, and is refused rather than truncated.
///
/// [redactedAreas] is the count of areas the owner painted over before
/// uploading, burned into the pixels. It is stored so the list can state a
/// fact — "2 areas hidden" — rather than offer a reassurance.
class VehicleDocument {
  final String id;
  final DocumentType type;
  final String title;

  /// Empty for everything uploaded since the bytes moved into Firestore. Kept
  /// on the model because a document uploaded to Cloud Storage one day would
  /// use them, and because dropping a field that might exist in a stored
  /// record loses it silently.
  final String fileUrl;
  final String storagePath;

  final String contentType; // image/jpeg
  final int sizeBytes;
  final bool isSharedWithBuyers;
  final String uploadedByOwnerId;
  final DateTime uploadedAt;

  /// How many areas the owner blacked out before this was saved.
  final int redactedAreas;

  const VehicleDocument({
    required this.id,
    required this.type,
    required this.title,
    this.fileUrl = '',
    this.storagePath = '',
    this.contentType = '',
    this.sizeBytes = 0,
    this.isSharedWithBuyers = false,
    required this.uploadedByOwnerId,
    required this.uploadedAt,
    this.redactedAreas = 0,
  });

  bool get isPdf => contentType.contains('pdf');

  /// The bytes are in Firestore rather than behind a URL. True for everything
  /// uploaded since the move; the getter exists so a viewer knows which way to
  /// fetch without asking the repository.
  bool get isInline => fileUrl.isEmpty;

  bool get wasRedacted => redactedAreas > 0;

  String get displayTitle => title.trim().isNotEmpty ? title.trim() : type.label;

  /// Human-readable size, for the list row.
  String get sizeLabel {
    if (sizeBytes <= 0) return '';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).round()} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory VehicleDocument.fromFirestore(Map<String, dynamic> data, String id) {
    return VehicleDocument(
      id: id,
      type: DocumentType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => DocumentType.other,
      ),
      title: data['title'] ?? '',
      fileUrl: data['fileUrl'] ?? '',
      storagePath: data['storagePath'] ?? '',
      contentType: data['contentType'] ?? '',
      sizeBytes: (data['sizeBytes'] ?? 0) is int
          ? (data['sizeBytes'] ?? 0)
          : int.tryParse('${data['sizeBytes']}') ?? 0,
      isSharedWithBuyers: data['isSharedWithBuyers'] == true,
      uploadedByOwnerId: data['uploadedByOwnerId'] ?? '',
      uploadedAt: (data['uploadedAt'] as dynamic)?.toDate() ?? DateTime.now(),
      redactedAreas: (data['redactedAreas'] ?? 0) is int
          ? (data['redactedAreas'] ?? 0)
          : int.tryParse('${data['redactedAreas']}') ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'type': type.name,
        'title': title,
        'fileUrl': fileUrl,
        'storagePath': storagePath,
        'contentType': contentType,
        'sizeBytes': sizeBytes,
        'isSharedWithBuyers': isSharedWithBuyers,
        'uploadedByOwnerId': uploadedByOwnerId,
        'uploadedAt': uploadedAt,
        'redactedAreas': redactedAreas,
      };
}
