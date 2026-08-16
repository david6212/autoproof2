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
/// Note on unsharing: Firebase Storage download URLs carry their own access
/// token, so turning sharing off removes a document from the buyer's view but
/// does not invalidate a URL somebody already copied. Deleting the document is
/// what actually revokes it — [DocumentRepository.deleteDocument] removes the
/// file, not just the record.
class VehicleDocument {
  final String id;
  final DocumentType type;
  final String title;
  final String fileUrl;
  final String storagePath; // needed to actually delete the file
  final String contentType; // image/jpeg, application/pdf
  final int sizeBytes;
  final bool isSharedWithBuyers;
  final String uploadedByOwnerId;
  final DateTime uploadedAt;

  const VehicleDocument({
    required this.id,
    required this.type,
    required this.title,
    required this.fileUrl,
    required this.storagePath,
    this.contentType = '',
    this.sizeBytes = 0,
    this.isSharedWithBuyers = false,
    required this.uploadedByOwnerId,
    required this.uploadedAt,
  });

  bool get isPdf => contentType.contains('pdf');

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
      };
}
