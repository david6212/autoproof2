
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

  // `uploadServiceReceipt` was removed on 26/09. It returned a tokenised
  // download URL, and that URL was written into the service record — a
  // document any visitor can read while the car is listed. A Storage token is
  // not a Firestore rule: closing the listing did not revoke it. Receipts now
  // live in `vehicles/{id}/services/{sid}/file/blob`, owner-only, beside the
  // licence scans. See `ServiceRepository.setReceipt`.
}
