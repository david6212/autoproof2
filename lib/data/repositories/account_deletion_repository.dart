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
/// ## Why this is not a loop of `.delete()` calls
///
/// **Deleting a Firestore document does not touch its subcollections.** That
/// is a rule of the database, not an oversight, and until 29/08 this class
/// ignored it: it deleted `vehicles/{id}` and moved on, leaving behind the
/// licence scan (an ID number and a home address), the whole service history,
/// the running costs, and — under `cars/{id}/private` — the plate, the single
/// field the app works hardest to keep out of a public document. The privacy
/// policy told the user all of it was gone.
///
/// So every subcollection is emptied explicitly, and **children go before
/// parents**, for two independent reasons:
///
/// - a child left behind is unreachable but not deleted, which is retention,
///   not erasure; and
/// - several child rules authorise through a `get()` on the parent
///   (`cars/{id}/private` asks `carSellerId(carId)`, everything under
///   `vehicles/{id}` asks `vehicleData(vehicleId).ownerId`). Delete the parent
///   first and that lookup returns null, so the child becomes undeletable by
///   anyone, forever.
///
/// ## Why the user document goes FIRST
///
/// Service records are append-only — `allow delete: if false` — so a seller
/// cannot erase an inconvenient service while a buyer is reading the history.
/// The right to erasure says a person may take their data with them. Both are
/// right, and the only thing that separates them is whether the account still
/// exists. So `users/{uid}` is deleted first, and the rules grant the erasure
/// exception on `!exists(users/{uid})` — see `isErasingAccount()` in
/// `firestore.rules`. Nobody launders a service history this way: it costs
/// them the entire account, which is a far higher price than the record.
///
/// The Firebase Auth user still goes **last**. Once it is gone there is no
/// `request.auth.uid`, and every rule in this app is written around that uid;
/// deleting the credential first would strand the data it was meant to take
/// with it.
///
/// ## What this deliberately does not reach
///
/// Documents this user wrote inside **other people's** collections that are
/// keyed by uid — a fuel-price report, a garage review, a like or a journey on
/// somebody else's listing. Finding them needs a `collectionGroup` query per
/// collection, an index for each, and `list` permission the rules do not grant.
/// None of them carries a name, an address or a plate. They are a known
/// residue, recorded here rather than quietly left out.
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
  ///
  /// Safe to retry after a failure part-way through: every step deletes what
  /// it finds, and the erasure exception the rules grant keys on the user
  /// document being absent, which stays true across a retry.
  Future<void> deleteEverything() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;

    // 1. The profile document, FIRST — it is what tells the rules this is an
    //    erasure and not an edit. Everything below depends on it being gone.
    await _firestore.collection('users').doc(uid).delete();

    // 2. What lived under the profile.
    for (final sub in const ['saved', 'past_vehicles']) {
      await _deleteAll(_firestore.collection('users').doc(uid).collection(sub));
    }

    // 3. Vehicle passports. The purchase price, the previous keeper, the
    //    service history, and the attached scans — a licence carries an ID
    //    number and a home address, and its bytes live one level below the
    //    record that describes it.
    final vehicles = await _firestore
        .collection('vehicles')
        .where('ownerId', isEqualTo: uid)
        .get();
    for (final vehicle in vehicles.docs) {
      final documents = await vehicle.reference.collection('documents').get();
      for (final document in documents.docs) {
        // The bytes before the record: a blob whose parent is gone is an
        // image still readable to anyone who knows the path.
        await _deleteAll(document.reference.collection('file'));
        await document.reference.delete();
      }
      for (final sub in const ['services', 'reminders', 'expenses']) {
        await _deleteAll(vehicle.reference.collection(sub));
      }
      await vehicle.reference.delete();
    }

    // 4. Listings. They carry a plate and a description this person wrote, and
    //    a listing with no seller is a dead advert nobody can remove.
    final listings = await _firestore
        .collection('cars')
        .where('sellerId', isEqualTo: uid)
        .get();
    for (final listing in listings.docs) {
      for (final sub in const [
        'private', // the plate
        'journeys',
        'buyer_likes',
        'seller_likes',
      ]) {
        await _deleteAll(listing.reference.collection(sub));
      }
      // Only a note's own author may delete it — not even the seller can
      // censor one. So this removes the notes this person wrote and leaves
      // other people's words about the car alone, which is the same rule the
      // app enforces everywhere else.
      await _deleteAll(
        listing.reference.collection('notes').where('authorUid', isEqualTo: uid),
      );
      await listing.reference.delete();
    }

    // 5. The credential itself.
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw AccountDeletionNeedsRecentLogin();
      }
      rethrow;
    }
  }

  /// Deletes every document a query returns, in batches.
  ///
  /// Batched rather than one call per document because a documented passport
  /// can hold hundreds of records, and a delete that takes a minute is a
  /// delete people interrupt. 400 leaves headroom under Firestore's 500-write
  /// batch limit.
  Future<void> _deleteAll(Query<Map<String, dynamic>> query) async {
    final snapshot = await query.get();
    if (snapshot.docs.isEmpty) return;

    var batch = _firestore.batch();
    var pending = 0;
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
      pending++;
      if (pending == 400) {
        await batch.commit();
        batch = _firestore.batch();
        pending = 0;
      }
    }
    if (pending > 0) await batch.commit();
  }
}

/// Firebase refuses to delete a credential on a stale sign-in.
///
/// Not an error to swallow: the data above is already gone, so the caller has
/// to say plainly what happened rather than reporting a generic failure.
class AccountDeletionNeedsRecentLogin implements Exception {}
