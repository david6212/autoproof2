import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Two claims the car page was making that it could not back.
///
/// Both were found by looking at the deployed page rather than at the code —
/// a screenshot of a live demo listing, 24/08. Neither is a rendering bug;
/// both are sentences that are false about the listing they sit on.
///
/// `_RegistryUnreachableNote` and `_SellerCard` are private to the screen and
/// the screen needs Firestore to build, so these read the source. That is the
/// same trade `plate_not_public_test` makes: a weaker test that runs beats a
/// stronger one that does not exist.
void main() {
  final src =
      File('lib/presentation/screens/buyer/car_detail_screen.dart')
          .readAsStringSync();

  test('no plate means nothing to reach, not a failed attempt', () {
    // `cars/{id}` stopped carrying the plate when it moved to the seller-only
    // subdocument. So a listing with no stored registry snapshot arrives with
    // `plate: ''`, the lookup fails on the empty string, and the reader was
    // shown "לא הצלחנו להגיע למרשם הרכב" — an outage that never happened —
    // over a "נסו שוב" button that could never succeed.
    final note = src.substring(src.indexOf('class _RegistryUnreachableNote'));
    expect(note, contains('if (car.plate.isEmpty) return const SizedBox.shrink();'));
    // The guard has to come before the watch, or the provider still runs.
    expect(note.indexOf('car.plate.isEmpty'),
        lessThan(note.indexOf('ref.watch(govDataForPlateProvider')));
  });

  test('the seller card describes the seller, not the registry', () {
    // `sellerType` is a radio button on the publish form. The old subtitle
    // reported it as a state record — and `checkScopeNote`, printed inside
    // the same card, already said "המוכר סומן לפי הסיווג שבחר. לא אימתנו את
    // זהותו ולא את בעלותו על הרכב".
    // The switch arm itself, not the class: the doc comment above it quotes
    // the old wording on purpose, and a scan of the whole class would read
    // that quotation as the claim still being made.
    final card = src.substring(src.indexOf('class _SellerCard'));
    expect(card,
        contains("SellerType.private => 'המוכר מסר שהרכב שלו',"));
    expect(card.contains("SellerType.private => 'הרכב רשום"), isFalse);
  });

  test('the registry ownership class is still shown, from the lookup', () {
    // Removing the claim from the seller card loses nothing: the real figure
    // has its own row in תובנות שווי, read from the listing's gov fields.
    expect(src, contains("label: 'סוג בעלות'"));
    expect(src, contains('car.isPrivateOwnership'));
  });
}
