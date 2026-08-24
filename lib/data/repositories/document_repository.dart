import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/document_redactor.dart';
import '../models/vehicle_document.dart';

/// Files attached to a vehicle passport, the sharing switch on each one, and
/// the black boxes burned into them before they were saved.
///
/// **The bytes live in Firestore, not Cloud Storage.** Storage needs the Blaze
/// plan and this project does not have it, which is why every upload in the
/// app failed at the network call for months. A Firestore document holds 1 MiB
/// and a resized licence is well under that, so the file goes into a `file`
/// subcollection under its own record — down one level, so listing the drawer
/// does not download every scan in it.
///
/// The move is not only a workaround. A Storage download URL carries its own
/// access token and keeps working after the owner turns sharing off; a
/// Firestore read is checked against the rules every single time. Unsharing
/// here actually revokes.
class DocumentRepository {
  DocumentRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// What one document may weigh once resized and re-encoded. Firestore's own
  /// ceiling is 1 MiB per document; the rest is room for the field names and
  /// the blob's length prefix.
  static const maxBytes = DocumentRedactor.maxBytes;

  /// The single document inside the `file` subcollection. A fixed id rather
  /// than a generated one so the file can be read, replaced and deleted
  /// without a lookup.
  static const _blobId = 'blob';

  CollectionReference<Map<String, dynamic>> _documents(String vehicleId) =>
      _db.collection('vehicles').doc(vehicleId).collection('documents');

  DocumentReference<Map<String, dynamic>> _blob(
          String vehicleId, String documentId) =>
      _documents(vehicleId).doc(documentId).collection('file').doc(_blobId);

  /// Everything on this vehicle — the owner's view. Metadata only.
  Stream<List<VehicleDocument>> watchDocuments(String vehicleId) =>
      _documents(vehicleId).snapshots().map(_sorted);

  /// Only what the owner chose to publish — the buyer's view.
  ///
  /// The `where` is not just a filter, it is what makes the read legal: the
  /// security rule grants a non-owner access to shared documents only, and
  /// Firestore refuses a query that could return documents the rules would
  /// deny. Dropping this clause turns the whole list into a permission error.
  Future<List<VehicleDocument>> sharedDocuments(String vehicleId) async {
    final snap = await _documents(vehicleId)
        .where('isSharedWithBuyers', isEqualTo: true)
        .get();
    return _sorted(snap);
  }

  /// The image itself, fetched only when someone opens it.
  ///
  /// Null when the record has no file — a document written before the bytes
  /// moved into Firestore, or one whose blob was removed. The caller shows
  /// that as a missing file rather than as a blank image.
  Future<Uint8List?> fileBytes(String vehicleId, String documentId) async {
    final snap = await _blob(vehicleId, documentId).get();
    final data = snap.data();
    final blob = data?['bytes'];
    return blob is Blob ? blob.bytes : null;
  }

  static List<VehicleDocument> _sorted(QuerySnapshot<Map<String, dynamic>> s) {
    final list = [
      for (final d in s.docs) VehicleDocument.fromFirestore(d.data(), d.id),
    ];
    list.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    return list;
  }

  /// Saves an already-redacted image and its record. Returns the new id.
  ///
  /// The bytes must have been through [DocumentRedactor] — this is where they
  /// stop being changeable, and a file that arrives here unprocessed still
  /// carries its EXIF block and whatever the owner meant to paint over. The
  /// size check is a backstop, not the mechanism.
  ///
  /// The file is written BEFORE the record. A record with no file shows as a
  /// broken row; a file with no record is invisible and unreachable, and the
  /// next upload's cleanup would not know to remove it.
  Future<String> saveDocument({
    required String uid,
    required String vehicleId,
    required RedactedDocument redacted,
    required DocumentType type,
    required String title,
    bool shareWithBuyers = false,
  }) async {
    if (redacted.bytes.lengthInBytes > maxBytes) {
      throw ArgumentError('הקובץ גדול מדי');
    }

    final docRef = _documents(vehicleId).doc();

    await _blob(vehicleId, docRef.id).set({
      'bytes': Blob(redacted.bytes),
      'width': redacted.width,
      'height': redacted.height,
    });

    final document = VehicleDocument(
      id: docRef.id,
      type: type,
      title: title,
      contentType: 'image/jpeg',
      sizeBytes: redacted.bytes.lengthInBytes,
      isSharedWithBuyers: shareWithBuyers,
      uploadedByOwnerId: uid,
      uploadedAt: DateTime.now(),
      redactedAreas: redacted.boxCount,
    );
    await docRef.set(document.toFirestore());
    return docRef.id;
  }

  Future<void> setShared(
    String vehicleId,
    String documentId,
    bool isShared,
  ) =>
      _documents(vehicleId)
          .doc(documentId)
          .update({'isSharedWithBuyers': isShared});

  Future<void> rename(String vehicleId, String documentId, String title) =>
      _documents(vehicleId).doc(documentId).update({'title': title.trim()});

  /// Deletes the record **and the file**.
  ///
  /// The file first: a record whose blob survived would leave the image
  /// readable to anyone who knew the path, and deleting a Firestore document
  /// does not touch its subcollections. That is a rule of the database, not an
  /// oversight, and it is the reason this method exists rather than a plain
  /// `.delete()` at the call site.
  Future<void> deleteDocument(String vehicleId, VehicleDocument document) async {
    await _blob(vehicleId, document.id).delete();
    await _documents(vehicleId).doc(document.id).delete();
  }
}
