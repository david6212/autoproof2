import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Uploads listing photos to Firebase Storage and returns their download URLs.
class StorageRepository {
  StorageRepository({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<List<String>> uploadCarPhotos({
    required String uid,
    required String listingId,
    required List<XFile> photos,
  }) async {
    final urls = <String>[];
    for (var i = 0; i < photos.length; i++) {
      final bytes = await photos[i].readAsBytes();
      final ref = _storage.ref('cars/$uid/$listingId/$i.jpg');
      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  /// Uploads a receipt for one service record and returns its URL.
  ///
  /// The path starts with the owner's uid because Storage rules cannot read
  /// Firestore — the only ownership they can check is the one written into the
  /// path. It must match the `vehicles/{uid}/{vehicleId}/receipts/` rule.
  Future<String> uploadServiceReceipt({
    required String uid,
    required String vehicleId,
    required String serviceId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final ext = contentType.contains('pdf') ? 'pdf' : 'jpg';
    final ref = _storage.ref('vehicles/$uid/$vehicleId/receipts/$serviceId.$ext');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }
}
