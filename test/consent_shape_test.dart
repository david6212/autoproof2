import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The shape of the consent sheet, pinned separately from its wording.
///
/// The wording was softened on 25/08 because it read like a legal notice. The
/// SHAPE is what must not soften with it, and it is the part somebody will
/// reasonably ask to change again — a cookie banner with one "הבנתי" button is
/// the most common pattern on the Israeli web, and it is the pattern that
/// costs money.
///
/// Three rules, each from a different authority, all pointing the same way:
/// implied consent from continued use is not consent (CJEU, Planet49); refusal
/// must be as easy as acceptance (CNIL fined Google €150M over exactly this
/// asymmetry); and Apple rejects under §5.1.1(ii) for collection without a
/// real choice. A friendlier sheet that cannot ship is not friendlier.
void main() {
  final gate = File('lib/presentation/widgets/analytics_consent_gate.dart')
      .readAsStringSync();

  test('there are two answers, not an acknowledgement', () {
    // One button labelled "understood" is the pattern this test exists to
    // refuse. Both answers must be reachable in one tap from the sheet.
    expect(gate, contains('answer(AnalyticsConsent.declined)'));
    expect(gate, contains('answer(AnalyticsConsent.granted)'));
    for (final acknowledgement in ['הבנתי', 'אישור', 'סגור']) {
      expect(gate.contains("Text('$acknowledgement')"), isFalse,
          reason: '"$acknowledgement" is an acknowledgement, not a choice');
    }
  });

  test('both buttons are the same widget, size and weight', () {
    // Not a filled accept beside a text-link decline. `ethics_test` carries
    // the general rule; this pins it at the one screen where it decides
    // whether the consent is legally valid at all.
    expect('OutlinedButton('.allMatches(gate).length, greaterThanOrEqualTo(2));
    expect('minimumSize: const Size.fromHeight(48)'.allMatches(gate).length,
        greaterThanOrEqualTo(2));
  });

  test('nothing claims that carrying on is agreement', () {
    for (final implied in [
      'המשך גלישה',
      'המשך שימוש',
      'מהווה הסכמה',
      'בהמשך השימוש',
    ]) {
      expect(gate.contains(implied), isFalse, reason: implied);
    }
  });

  test('the recipient and the identifier are still named', () {
    // Softer wording may not become vaguer wording: informed consent has to
    // say who receives the data and what is stored. Both moved down the sheet;
    // neither was dropped.
    expect(gate, contains('Firebase Analytics'));
    expect(gate, contains('מזהה מתמשך'));
  });

  test('the sheet says the app works either way', () {
    // Consent is not freely given if refusing costs you the product.
    expect(gate, contains('עובדת בדיוק אותו דבר בשתי האפשרויות'));
  });

  test('the answer is reversible, and the sheet says where', () {
    expect(gate, contains('בפרופיל'));
  });
}
