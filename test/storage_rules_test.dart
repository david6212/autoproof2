import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A vehicle licence must not be readable by the world (HALT-11).
///
/// `firestore.rules` keeps a document's *record* shut until the owner shares
/// it and the car is listed. `storage.rules` used to grant `allow read: if
/// true` on the file itself — and in Storage rules `read` covers `list`, so
/// the whole `vehicles/{uid}/` prefix was enumerable by anyone with the SDK.
/// An ID number and a home address sit inside those files.
///
/// Nothing broke by closing it, because a buyer never reads a file by path:
/// the download URL on the Firestore record carries its own access token and
/// bypasses these rules. `read` here governs SDK access, which only the owner
/// ever performs.
///
/// This test exists because the bucket does not. The rules cannot be exercised
/// against the emulator until Storage is provisioned, and the day it is
/// provisioned is the day a mistake here goes live — so the file is pinned as
/// source until then.
void main() {
  final rules = File('storage.rules').readAsStringSync();

  /// The body of one `match` block, so a claim about the passport paths cannot
  /// accidentally pass on the photos block above it.
  String block(String path) {
    final start = rules.indexOf('match $path');
    expect(start, greaterThan(-1), reason: 'no rule for $path');
    final end = rules.indexOf('match /', start + 1);
    return rules.substring(start, end == -1 ? rules.length : end);
  }

  test('passport documents are readable only by their owner', () {
    final b = block('/vehicles/{uid}/{vehicleId}/documents/{fileName}');
    expect(b, contains('allow read: if isOwner(uid);'));
    expect(b.contains('allow read: if true'), isFalse);
  });

  test('service receipts are readable only by their owner', () {
    // A garage invoice carries a name, a plate and often an address.
    final b = block('/vehicles/{uid}/{vehicleId}/receipts/{fileName}');
    expect(b, contains('allow read: if isOwner(uid);'));
    expect(b.contains('allow read: if true'), isFalse);
  });

  test('listing photos stay public — that one is on purpose', () {
    // Published deliberately, shown before sign-in. Closing it would break the
    // marketplace and protect nothing.
    expect(block('/cars/{uid}/{listingId}/{fileName}'),
        contains('allow read: if true;'));
  });

  test('every write path is gated on the uid in the path', () {
    // Storage rules cannot read Firestore, so ownership has to be in the path.
    // A write rule that forgot isOwner would let any signed-in user overwrite
    // another person's licence.
    for (final line in rules
        .split('\n')
        .where((l) => l.contains('allow write:') || l.contains('allow delete:'))
        .where((l) => !l.contains('if false'))) {
      expect(line, contains('isOwner(uid)'), reason: line.trim());
    }
  });

  test('anything not named is refused', () {
    expect(rules, contains('''match /{allPaths=**} {
      allow read, write: if false;'''));
  });

  test('uploads still cannot reach a bucket that does not exist', () {
    // The flag and these rules go live together. If storageEnabled is ever
    // flipped, this test is the reminder that the bucket must be in eur3 to
    // match Firestore, and that these rules must be deployed first.
    final config =
        File('lib/core/constants/app_config.dart').readAsStringSync();
    expect(config, contains('storageEnabled = false'),
        reason: 'if this is now true, deploy storage.rules before the bucket '
            'and re-read the HALT-11 note in docs/audits/');
  });
}
