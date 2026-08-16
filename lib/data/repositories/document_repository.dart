import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/vehicle_document.dart';

/// Files attached to a vehicle passport, and the sharing switch on each one.
class DocumentRepository {
  DocumentRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  /// 10 MB. A phone photo of a certificate is ~2 MB and a scanned PDF ~1 MB;
  /// anything past this is someone uploading the wrong thing, and the free
  /// Storage quota is shared by every user of the app.
  static const maxBytes = 10 * 1024 * 1024;

  CollectionReference<Map<String, dynamic>> _documents(String vehicleId) =>
      _db.collection('vehicles').doc(vehicleId).collection('documents');

  /// Everything on this vehicle — the owner's view.
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

  static List<VehicleDocument> _sorted(QuerySnapshot<Map<String, dynamic>> s) {
    final list = [
      for (final d in s.docs) VehicleDocument.fromFirestore(d.data(), d.id),
    ];
    list.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    return list;
  }

  /// Uploads a file and records it. Returns the new document id.
  ///
  /// The storage path starts with the owner's uid because Storage rules cannot
  /// read Firestore — the only thing they can check is the path itself, so
  /// ownership has to be written into it.
  Future<String> uploadDocument({
    required String uid,
    required String vehicleId,
    required Uint8List bytes,
    required String fileName,
    required DocumentType type,
    required String title,
    String contentType = 'application/octet-stream',
    bool shareWithBuyers = false,
  }) async {
    if (bytes.lengthInBytes > maxBytes) {
      throw ArgumentError('הקובץ גדול מדי — עד 10MB');
    }

    final docRef = _documents(vehicleId).doc();
    final safeName = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final path = 'vehicles/$uid/$vehicleId/documents/${docRef.id}_$safeName';

    final ref = _storage.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();

    final document = VehicleDocument(
      id: docRef.id,
      type: type,
      title: title,
      fileUrl: url,
      storagePath: path,
      contentType: contentType,
      sizeBytes: bytes.lengthInBytes,
      isSharedWithBuyers: shareWithBuyers,
      uploadedByOwnerId: uid,
      uploadedAt: DateTime.now(),
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
  /// Deleting only the Firestore record would leave a live download URL: a
  /// Storage URL carries its own access token and keeps working even once
  /// nothing links to it. For a document someone wants gone, that is not good
  /// enough. If the file is already missing the record is still removed.
  Future<void> deleteDocument(String vehicleId, VehicleDocument document) async {
    if (document.storagePath.isNotEmpty) {
      try {
        await _storage.ref(document.storagePath).delete();
      } on FirebaseException catch (e) {
        if (e.code != 'object-not-found') rethrow;
      }
    }
    await _documents(vehicleId).doc(document.id).delete();
  }
}
