import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Deleting an account has to actually delete it.
///
/// Apple's §5.1.1(v) requires in-app deletion for any app that creates
/// accounts. What this app had was a *request*: a document written to
/// `data_corrections`, a collection whose rules are `allow read: if false`,
/// waiting for a human to notice it in a console. That is a rejection at
/// review, and a promise the code could not keep.
void main() {
  final repo =
      File('lib/data/repositories/account_deletion_repository.dart')
          .readAsStringSync();

  test('everything the account owns is removed', () {
    for (final collection in const ['cars', 'vehicles', 'users']) {
      expect(repo, contains("collection('$collection')"),
          reason: '$collection holds data belonging to the account');
    }
    for (final sub in const ['saved', 'past_vehicles']) {
      expect(repo, contains("'$sub'"));
    }
  });

  test('the credential is deleted last', () {
    // Once the Firebase Auth user is gone there is no request.auth.uid, and
    // every rule in this app is written around it — deleting it first would
    // strand the data it was meant to take with it.
    expect(repo.indexOf("collection('users').doc(uid).delete()") <
        repo.indexOf('user.delete()'), isTrue);
  });

  test('a stale sign-in is reported, not swallowed', () {
    // Firebase refuses to delete a credential on an old sign-in. By then the
    // data is already gone, so a generic "failed" would be a lie.
    expect(repo, contains('requires-recent-login'));
    expect(repo, contains('AccountDeletionNeedsRecentLogin'));

    final profile = File('lib/presentation/screens/shared/profile_screen.dart')
        .readAsStringSync();
    expect(profile, contains('AccountDeletionNeedsRecentLogin'));
  });

  test('the dialog says what will go before it goes', () {
    final profile = File('lib/presentation/screens/shared/profile_screen.dart')
        .readAsStringSync();
    expect(profile, contains('אי אפשר לבטל'));
    expect(profile, contains('תיקי הרכב'));
  });
}
