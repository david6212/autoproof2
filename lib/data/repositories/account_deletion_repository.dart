import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// What "delete my account" actually deletes.
///
/// Apple requires an app that creates accounts to delete them **in the app**
/// (App Store Review Guidelines §5.1.1(v)), and until 2026-08-22 this app
/// offered a *request*: a row written to `data_corrections`, a collection no
/// client can read, waiting for somebody to notice it in a console. That is
/// an automatic rejection, and — more to the point — a promise the product
/// could not keep.
///
/// The order below matters. The Firebase Auth user goes **last**: once it is
/// gone there is no `request.auth.uid`, and every Firestore rule in this app
/// is written around that uid. Deleting the credential first would strand the
/// data it was supposed to take with it.
class AccountDeletionRepository {
  AccountDeletionRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// Deletes everything this account owns, then the account.
  ///
  /// Throws [AccountDeletionNeedsRecentLogin] when Firebase refuses because
  /// the sign-in is old — which it does for a destructive operation, by
  /// design. The caller signs the user in again and retries.
  Future<void> deleteEverything() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;

    // 1. Listings. They carry a plate and a description this person wrote,
    //    and a listing with no seller is a dead advert nobody can remove.
    final listings = await _firestore
        .collection('cars')
        .where('sellerId', isEqualTo: uid)
        .get();
    for (final doc in listings.docs) {
      await doc.reference.delete();
    }

    // 2. Vehicle passports. Private to the owner already; they hold the
    //    purchase price and the previous keeper.
    final vehicles = await _firestore
        .collection('vehicles')
        .where('ownerId', isEqualTo: uid)
        .get();
    for (final doc in vehicles.docs) {
      await doc.reference.delete();
    }

    // 3. The user document and the two collections under it.
    for (final sub in const ['saved', 'past_vehicles']) {
      final docs =
          await _firestore.collection('users').doc(uid).collection(sub).get();
      for (final d in docs.docs) {
        await d.reference.delete();
      }
    }
    await _firestore.collection('users').doc(uid).delete();

    // 4. The credential itself.
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw AccountDeletionNeedsRecentLogin();
      }
      rethrow;
    }
  }
}

/// Firebase refuses to delete a credential on a stale sign-in.
///
/// Not an error to swallow: the data above is already gone, so the caller has
/// to say plainly what happened rather than reporting a generic failure.
class AccountDeletionNeedsRecentLogin implements Exception {}
