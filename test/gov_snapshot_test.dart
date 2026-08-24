import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/data/models/gov_data_model.dart';

/// The registry answer a listing carries, so a buyer never needs the plate.
///
/// `cars/{id}` is world-readable. As long as the plate lives there, masking it
/// on screen is decoration — anyone with `curl` reads it. The way out is for
/// the listing to carry the ANSWER instead of the question, which only works
/// if the answer survives a round trip through Firestore intact.
void main() {
  GovData sample() => GovData(
        plate: '11111111',
        chassis: 'JMZKF6W7A00123456',
        make: 'מאזדה',
        commercialName: 'CX-5',
        model: 'KF6W7',
        year: 2017,
        color: 'אפור',
        fuelType: 'בנזין',
        ownershipType: 'פרטי',
        trim: 'PREMIUM',
        lastTestDate: DateTime(2026, 7, 21),
        licenseExpiry: DateTime(2027, 7, 19),
        safetyRating: '7',
        lastTestKm: 53200,
        structuralChange: true,
        recalls: const [
          RecallItem(system: 'בלמים', description: 'תקלה סידרתית', date: '2025-01-01'),
        ],
        missingDatasets: const {GovDataset.recalls},
      );

  test('the plate and the VIN are never written into a listing', () {
    final snap = sample().toSnapshot();
    final flat = snap.toString();

    expect(flat.contains('11111111'), isFalse,
        reason: 'the plate is the thing this exists to keep out');
    expect(flat.contains('JMZKF6W7A00123456'), isFalse,
        reason: 'the VIN identifies a car more permanently than the plate');
    expect(snap.containsKey('plate'), isFalse);
    expect(snap.containsKey('chassis'), isFalse);
  });

  test('everything a buyer is shown survives the round trip', () {
    final back = GovData.fromSnapshot(sample().toSnapshot());

    expect(back.make, 'מאזדה');
    expect(back.commercialName, 'CX-5');
    expect(back.year, 2017);
    expect(back.lastTestKm, 53200);
    expect(back.structuralChange, isTrue);
    expect(back.lastTestDate, DateTime(2026, 7, 21));
    expect(back.licenseExpiry, DateTime(2027, 7, 19));
    expect(back.recalls.single.system, 'בלמים');
  });

  test('a dataset that did not answer stays unanswered', () {
    // The one substitution this app refuses: "we never reached the recall
    // list" must not come back as "no recalls". If the gap were dropped from
    // the snapshot, every stored listing would quietly claim a clean check.
    final back = GovData.fromSnapshot(sample().toSnapshot());
    expect(back.answered(GovDataset.recalls), isFalse);
    expect(back.answered(GovDataset.history), isTrue);
  });

  test('an empty or partial map does not throw', () {
    // Listings published before this existed, and anything Firestore hands
    // back half-formed.
    final back = GovData.fromSnapshot(const {});
    expect(back.make, '');
    expect(back.year, 0);
    expect(back.recalls, isEmpty);
    expect(back.plate, isEmpty);
  });
}
