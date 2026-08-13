// The odometer check is the thing the product exists to catch, and it sat
// written but unwired. Pinned here so it stays connected and keeps saying
// what it is allowed to say.

import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/core/utils/validators.dart';

String? check(int entered, int? lastTest) =>
    Validators.kmAgainstLastTest(enteredKm: entered, lastTestKm: lastTest);

void main() {
  group('km against the last official test', () {
    test('raises when the entered reading is lower', () {
      final msg = check(41000, 143851);
      expect(msg, isNotNull);
      // Both numbers must appear — a warning without them is unactionable.
      expect(msg, contains('41,000'));
      expect(msg, contains('143,851'));
    });

    test('says nothing when the reading is higher, as it should be', () {
      expect(check(150000, 143851), isNull);
    });

    test('says nothing when the readings match exactly', () {
      expect(check(143851, 143851), isNull);
    });

    test('says nothing when the car has no official reading', () {
      // Plenty of cars are absent from the history dataset; that is not a
      // finding about the seller.
      expect(check(41000, null), isNull);
    });

    test('rejects a negative reading outright', () {
      expect(check(-1, 143851), 'קילומטראז\' לא תקין');
    });

    test('does not accuse anyone of rolling back an odometer', () {
      // BUSINESS_ROADMAP section 10: state the check, never label the person.
      final msg = check(41000, 143851)!;
      for (final banned in ['גלגול', 'זיוף', 'רמאות', 'שקר']) {
        expect(msg.contains(banned), isFalse, reason: 'must not say "$banned"');
      }
    });
  });

  group('thousands separators', () {
    test('group correctly at every length', () {
      expect(check(999, 1000), contains('999 ק"מ'));
      expect(check(1000, 20000), contains('1,000'));
      expect(check(20000, 1234567), contains('1,234,567'));
    });
  });
}
