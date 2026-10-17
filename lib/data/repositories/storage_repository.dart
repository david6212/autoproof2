
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

  /// Deletes every file this account owns in the bucket (SEC-04).
  ///
  /// Account deletion used to have no Storage step at all, while
  /// `storage.rules` makes `cars/{uid}/` world-readable and world-listable:
  /// the day the bucket exists, a deleted account would have left the photos
  /// of its car — often taken on its own driveway — in a public prefix, with
  /// the record that pointed at them gone. `vehicles/{uid}/` is swept too;
  /// it is reserved and unused, and sweeping it costs one empty listing.
  Future<void> deleteEverythingFor(String uid) async {
    for (final prefix in ['cars/$uid', 'vehicles/$uid']) {
      await _deleteTree(_storage.ref(prefix));
    }
  }

  Future<void> _deleteTree(Reference ref) async {
    final listing = await ref.listAll();
    for (final item in listing.items) {
      try {
        await item.delete();
      } on FirebaseException catch (e) {
        // Gone already is the outcome we wanted.
        if (e.code != 'object-not-found') rethrow;
      }
    }
    for (final sub in listing.prefixes) {
      await _deleteTree(sub);
    }
  }

  // `uploadServiceReceipt` was removed on 26/09. It returned a tokenised
  // download URL, and that URL was written into the service record — a
  // document any visitor can read while the car is listed. A Storage token is
  // not a Firestore rule: closing the listing did not revoke it. Receipts now
  // live in `vehicles/{id}/services/{sid}/file/blob`, owner-only, beside the
  // licence scans. See `ServiceRepository.setReceipt`.
}
