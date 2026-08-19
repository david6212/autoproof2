import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/data/sources/remote/gov_api_service.dart';

/// "Not in the registry" and "we never reached the registry" are opposite
/// answers, and for a long while the app could not tell them apart: the
/// provider caught everything and returned null, so a nationwide outage looked
/// exactly like a car with no records — panels quietly missing, nothing on
/// screen to explain it or to try again.
///
/// This is the distinction those panels now depend on.
void main() {
  group('why a lookup failed', () {
    test('a plate the registry has never heard of is an answer', () {
      final e = GovApiException('המספר לא נמצא. בדוק את מספר הרישוי.',
          kind: GovApiErrorKind.notFound);

      expect(e.isNotFound, isTrue);
    });

    test('a timeout is the absence of an answer', () {
      // Anything we did not hear back from defaults to unreachable, so a new
      // failure path added later errs towards saying "we could not check"
      // rather than towards silence.
      final e = GovApiException('הבקשה ארכה מדי. בדוק את החיבור לאינטרנט.');

      expect(e.kind, GovApiErrorKind.unreachable);
      expect(e.isNotFound, isFalse);
    });

    test('an unusable plate is neither', () {
      final e = GovApiException('יש להזין מספר רישוי.',
          kind: GovApiErrorKind.badInput);

      expect(e.isNotFound, isFalse);
      expect(e.kind, GovApiErrorKind.badInput);
    });

    test('the message still reads on its own', () {
      // It reaches users, so it stays a sentence rather than a code.
      expect(
        GovApiException('שגיאת רשת. נסה שוב.').toString(),
        'שגיאת רשת. נסה שוב.',
      );
    });
  });
}
