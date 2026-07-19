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
}
