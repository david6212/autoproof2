
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/core/constants/app_strings.dart';

/// The three screens a newcomer reads before anything else.
///
/// Rewritten 25/08. The first slide had been promising that a seller's own
/// classification is "מוצלב מול מרשם הרכב" — the exact claim removed from the
/// car page the day before as untrue, still being made in the app's opening
/// sentence. Onboarding is where a false claim does the most damage: it is
/// read first, by someone with no way to check it.
void main() {
  final slides = [
    (AppStrings.onboard1Title, AppStrings.onboard1Body),
    (AppStrings.onboard2Title, AppStrings.onboard2Body),
    (AppStrings.onboard3Title, AppStrings.onboard3Body),
  ];

  final all = slides.map((s) => '${s.$1} ${s.$2}').join(' ');

  test('nothing claims the seller is checked against the registry', () {
    // `sellerType` is a radio button on the publish form. Nothing verifies it,
    // and the crowd reports that once partly backed it are gone.
    expect(all.contains('מוצלב'), isFalse);
    for (final claim in ['מאומת', 'אימתנו', 'בדקנו את המוכר']) {
      expect(all.contains(claim), isFalse, reason: claim);
    }
  });

  test('the opening slide leads with the registry lookup', () {
    // It is the one thing here that no other Israeli app gives away, and it
    // used to be four words on the middle slide.
    expect(AppStrings.onboard1Title, contains('משרד התחבורה'));
    expect(AppStrings.onboard1Body, contains('בלי הרשמה'));
  });

  test('every capability named is one the app actually has', () {
    // Each of these is wired and tested elsewhere: the five per-vehicle
    // datasets, the odometer finding at the top of the car page, and the
    // append-only service log.
    expect(AppStrings.onboard1Body, contains('ריקולים'));
    expect(AppStrings.onboard2Body, contains('בטסט האחרון'));
    // Was 'לצמיתות' until David asked for the permanence clause to come out.
    // The screen now names the three fields a record actually carries.
    expect(AppStrings.onboard3Body, contains('המוסך'));
  });

  test('no slide oversells with a superlative', () {
    for (final word in ['הטוב ביותר', 'המוביל', 'מהפכ', 'בלעדי', '!']) {
      expect(all.contains(word), isFalse, reason: word);
    }
  });

  test('each slide is short enough to be read on a phone', () {
    for (final s in slides) {
      expect(s.$1.length, lessThanOrEqualTo(45), reason: s.$1);
      expect(s.$2.length, lessThanOrEqualTo(130), reason: s.$2);
    }
  });
}
