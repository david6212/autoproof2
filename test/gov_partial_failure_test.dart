import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/data/models/gov_data_model.dart';

/// One sulking endpoint used to erase every government fact on a listing.
///
/// `lookupPlate` hits five separate registry endpoints. Four of them were
/// awaited bare, so a timeout on any one threw out of the method,
/// `govDataForPlateProvider` swallowed it and returned null, and the car page
/// silently dropped the odometer comparison, the recall check and the
/// structural record together — the whole reason the app exists, gone because
/// one auxiliary dataset had a bad minute.
///
/// These pin the two halves of the repair: a gap stays a gap, and a gap is
/// never reported as a clean result.
void main() {
  GovData base() => GovData(
        plate: '00000000',
        make: 'טויוטה',
        commercialName: 'קורולה',
        model: 'קורולה',
        year: 2019,
        color: 'לבן',
        fuelType: 'בנזין',
        ownershipType: 'פרטי',
        trim: '',
        lastTestDate: DateTime(2026, 3, 1),
        licenseExpiry: DateTime(2027, 3, 1),
        safetyRating: '',
        chassis: '',
      );

  group('a dataset that did not answer', () {
    test('is remembered, not assumed empty', () {
      final data = base().withExtras(
        history: null,
        recalls: const [],
        missing: {GovDataset.history, GovDataset.recalls},
      );

      expect(data.answered(GovDataset.history), isFalse);
      expect(data.answered(GovDataset.recalls), isFalse);
      // Only two datasets are recorded as answerable now: the disability-tag
      // set was removed from the app entirely, because fetching health data
      // and choosing not to show it is still collecting it.
      expect(GovDataset.values.length, 2);
    });

    test('does not take the base record down with it', () {
      // The point of the repair. The plate, make, model and year come from the
      // one endpoint that must succeed; everything else is enrichment.
      final data = base().withExtras(
        history: null,
        recalls: const [],
        missing: {GovDataset.history, GovDataset.recalls},
      );

      expect(data.plate, '00000000');
      expect(data.make, 'טויוטה');
      expect(data.year, 2019);
      expect(data.licenseExpiry, isNotNull);
    });

    test('leaves the fields it would have filled empty rather than false', () {
      // `structuralChange: false` here means "we never looked", which is why
      // the UI has to consult [answered] before saying anything about it.
      final data = base().withExtras(
        history: null,
        recalls: const [],
        missing: {GovDataset.history},
      );

      expect(data.structuralChange, isFalse);
      expect(data.lastTestKm, isNull,
          reason: 'no odometer to compare against — say nothing, not zero');
    });
  });

  group('a lookup where everything answered', () {
    test('reports no gaps', () {
      final data = base().withExtras(
        history: {'kilometer_test_aharon': 94300, 'shinui_mivne_ind': 1},
        recalls: const [],
      );

      expect(data.missingDatasets, isEmpty);
      expect(data.answered(GovDataset.history), isTrue);
      expect(data.answered(GovDataset.recalls), isTrue);
      expect(data.lastTestKm, 94300);
      expect(data.structuralChange, isTrue);
    });

    test('an empty recall list means clean, and only then', () {
      // The whole distinction, in one assertion pair: identical `recalls`,
      // opposite meanings.
      final answered = base().withExtras(history: null, recalls: const []);
      final never = base().withExtras(
        history: null,
        recalls: const [],
        missing: {GovDataset.recalls},
      );

      expect(answered.recalls, isEmpty);
      expect(never.recalls, isEmpty);
      expect(answered.answered(GovDataset.recalls), isTrue);
      expect(never.answered(GovDataset.recalls), isFalse);
    });
  });
}
