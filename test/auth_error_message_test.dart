import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/data/repositories/auth_repository.dart';

/// What the app says when sign-in or phone verification fails.
///
/// Every failure used to arrive as "האימות נכשל. נסה שוב." — including the one
/// that actually happened: the release build's certificate had never been
/// registered in Firebase, so phone verification could not succeed for any
/// number, on any attempt. Telling somebody to try again in that situation
/// sends them in a circle and quietly blames them for our configuration.
void main() {
  group('a failure that is ours says so', () {
    test('an unauthorised build does not read as a bad phone number', () {
      for (final code in const [
        'app-not-authorized',
        'missing-client-identifier',
        'invalid-app-credential',
      ]) {
        final msg = AuthRepository.messageFor(code);
        expect(msg, contains('תקלה'));
        expect(msg.contains('נסה שוב'), isFalse,
            reason: 'retrying cannot fix a certificate that is not registered');
      }
    });

    test('an exhausted SMS quota is not the reader\'s number', () {
      expect(AuthRepository.messageFor('quota-exceeded'), contains('שלנו'));
    });
  });

  group('a failure the reader can act on tells them what to do', () {
    test('a wrong code asks for the digits again', () {
      expect(AuthRepository.messageFor('invalid-verification-code'),
          contains('הקוד שגוי'));
    });

    test('an expired code asks for a new one, not for the same one', () {
      final msg = AuthRepository.messageFor('session-expired');
      expect(msg, contains('קוד חדש'));
      expect(AuthRepository.messageFor('code-expired'), msg,
          reason: 'the two codes mean the same thing to the reader');
    });

    test('a number already on another account is not a typo', () {
      expect(AuthRepository.messageFor('credential-already-in-use'),
          contains('חשבון אחר'));
    });
  });

  test('the billing failure blames us, and offers the route that works', () {
    // Phone verification failed for twelve days with the cause recorded as
    // unknown. It is BILLING_NOT_ENABLED: Firebase phone auth needs the Blaze
    // plan. Until that is switched on the message must not leave the reader
    // checking their own number, and must point at Google sign-in, which
    // works today.
    for (final code in ['billing-not-enabled', 'BILLING_NOT_ENABLED']) {
      final msg = AuthRepository.messageFor(code);
      expect(msg, contains('לא '));
      expect(msg, contains('במספר שלך'));
      expect(msg, contains('Google'));
      expect(msg.contains('נסה שוב'), isFalse,
          reason: 'retrying cannot help until billing is enabled');
    }
  });

  test('anything unrecognised carries its code, so a screenshot names it', () {
    expect(AuthRepository.messageFor('some-new-code-2027'),
        contains('some-new-code-2027'));
  });
}
