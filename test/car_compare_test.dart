import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/core/utils/car_compare.dart';
import 'package:bonnetcheck/data/models/car_model.dart';
import 'package:bonnetcheck/data/models/gov_data_model.dart';
import 'package:bonnetcheck/data/models/model_spec.dart';
import 'package:bonnetcheck/presentation/providers/compare_provider.dart';

/// The comparison table is the one screen that tells a buyer which of their
/// shortlisted cars is better on a given measure. Getting a direction backwards
/// there — marking the HIGHEST mileage as the advantage — would be a confident,
/// wrong recommendation, and nothing on the screen would look broken.

CarModel car({
  String id = 'a',
  String plate = '11111111',
  double price = 100000,
  int year = 2020,
  int km = 60000,
  int hand = 1,
  String area = 'תל אביב',
  SellerType sellerType = SellerType.private,
  String fuel = 'בנזין',
  String color = 'לבן',
  ModelSpec? spec,
}) {
  return CarModel(
    id: id,
    plate: plate,
    make: 'מאזדה',
    model: 'CX-5',
    year: year,
    price: price,
    km: km,
    hand: hand,
    area: area,
    sellerId: 's',
    status: CarStatus.active,
    photos: const [],
    reasonForSelling: '',
    sellerType: sellerType,
    createdAt: DateTime(2026, 1, 1),
    fuel: fuel,
    color: color,
    spec: spec,
  );
}

GovData gov({
  int? lastTestKm,
  bool structuralChange = false,
  bool offRoad = false,
  List<RecallItem> recalls = const [],
  DateTime? licenseExpiry,
  String ownershipType = 'פרטי',
}) {
  return GovData(
    plate: '11111111',
    make: 'מאזדה',
    commercialName: 'CX-5',
    model: 'CX-5',
    year: 2020,
    color: 'לבן',
    fuelType: 'בנזין',
    ownershipType: ownershipType,
    trim: '',
    lastTestDate: null,
    licenseExpiry: licenseExpiry,
    safetyRating: null,
    chassis: '',
    pollutionGroup: '',
    engineModel: '',
    frontTire: '',
    rearTire: '',
    firstOnRoad: '',
    lastTestKm: lastTestKm,
    structuralChange: structuralChange,
    colorChanged: false,
    tireChanged: false,
    originality: 'פרטי',
    firstRegistration: '',
    recalls: recalls,
    offRoad: offRoad,
    offRoadDate: '',
    tozeretCd: '',
    degemCd: '',
  );
}

CompareRow rowNamed(List<CompareSection> sections, String label) {
  return sections.expand((s) => s.rows).firstWhere((r) => r.label == label);
}

void main() {
  group('which column wins a row', () {
    test('the cheapest price is the advantage, not the dearest', () {
      final sections = buildComparison([
        car(id: 'a', price: 120000),
        car(id: 'b', price: 90000),
      ]);
      expect(rowNamed(sections, 'מחיר').best, {1});
    });

    test('lowest km, lowest hand, lowest km-per-year all win low', () {
      final sections = buildComparison([
        car(id: 'a', km: 120000, hand: 3, year: 2018),
        car(id: 'b', km: 40000, hand: 1, year: 2018),
      ]);
      expect(rowNamed(sections, 'קילומטראז\'').best, {1});
      expect(rowNamed(sections, 'יד').best, {1});
      expect(rowNamed(sections, 'ק"מ בשנה').best, {1});
    });

    test('the NEWEST year wins — the one row where higher is better', () {
      final sections = buildComparison([
        car(id: 'a', year: 2016),
        car(id: 'b', year: 2022),
      ]);
      expect(rowNamed(sections, 'שנת ייצור').best, {1});
    });

    test('a tie marks nobody', () {
      // Ticking both columns says "these are the same", which the numbers
      // already said. It would only dilute the marks that mean something.
      final sections = buildComparison([
        car(id: 'a', price: 100000),
        car(id: 'b', price: 100000),
      ]);
      expect(rowNamed(sections, 'מחיר').best, isEmpty);
    });

    test('an unknown value never wins and never blocks the other column', () {
      final sections = buildComparison([
        car(id: 'a', spec: const ModelSpec(engineCc: 1600)),
        car(id: 'b'),
      ]);
      // Only one column knows its capacity, so there is nothing to compare.
      expect(rowNamed(sections, 'נפח מנוע').best, isEmpty);
    });
  });

  group('rows that deliberately pick no winner', () {
    test('seller type is classified, never ranked', () {
      // The whole positioning is that a dealer is labelled, not penalised.
      final sections = buildComparison([
        car(id: 'a', sellerType: SellerType.private),
        car(id: 'b', sellerType: SellerType.dealer),
      ]);
      final row = rowNamed(sections, 'סוג מוכר');
      expect(row.advantage, Advantage.none);
      expect(row.best, isEmpty);
    });

    test('a bigger engine is not an advantage', () {
      final sections = buildComparison([
        car(id: 'a', spec: const ModelSpec(engineCc: 2500)),
        car(id: 'b', spec: const ModelSpec(engineCc: 1200)),
      ]);
      expect(rowNamed(sections, 'נפח מנוע').best, isEmpty);
    });

    test('an electric model reads as having no capacity, not missing data', () {
      final sections = buildComparison([
        car(id: 'a', fuel: 'חשמל'),
        car(id: 'b', spec: const ModelSpec(engineCc: 1600)),
      ]);
      expect(rowNamed(sections, 'נפח מנוע').cells[0].text, 'אין (חשמלי)');
    });
  });

  group('official records', () {
    test('a listing under the last official reading is flagged as a drop', () {
      // The odometer-rollback signal. The listing claims 41,000 while the last
      // test recorded 143,851 — the Skoda demo case.
      final sections = buildComparison(
        [car(id: 'a', km: 41000), car(id: 'b', km: 92000)],
        gov: [gov(lastTestKm: 143851), gov(lastTestKm: 53200)],
      );
      final row = rowNamed(sections, 'התאמת ק"מ');
      expect(row.cells[0].tone, CellTone.bad);
      expect(row.cells[0].text, contains('102,851'));
      // Driving on after the test is normal, so the other car is fine.
      expect(row.cells[1].tone, CellTone.good);
      expect(row.cells[1].text, 'תואם');
    });

    test('a recorded structural change reads as a warning on its own', () {
      // Tone is per-cell, not relative: even if BOTH cars had one, both stay
      // red. A warning is not graded on a curve.
      final sections = buildComparison(
        [car(id: 'a'), car(id: 'b')],
        gov: [gov(structuralChange: true), gov(structuralChange: true)],
      );
      final row = rowNamed(sections, 'שינוי מבנה');
      expect(row.cells.map((c) => c.tone),
          everyElement(CellTone.bad));
    });

    test('fewer open recalls is the advantage, and none reads reassuring', () {
      final sections = buildComparison(
        [car(id: 'a'), car(id: 'b')],
        gov: [
          gov(recalls: [
            const RecallItem(system: 'בלמים', description: '', date: '')
          ]),
          gov(),
        ],
      );
      final row = rowNamed(sections, 'ריקולים פתוחים');
      expect(row.best, {1});
      expect(row.cells[1].text, 'אין');
      expect(row.cells[0].tone, CellTone.bad);
    });

    test('an expired licence is flagged, a valid one is not', () {
      final sections = buildComparison(
        [car(id: 'a'), car(id: 'b')],
        gov: [
          gov(licenseExpiry: DateTime(2020, 1, 1)),
          gov(licenseExpiry: DateTime(2099, 1, 1)),
        ],
      );
      final row = rowNamed(sections, 'תוקף רישיון');
      expect(row.cells[0].tone, CellTone.bad);
      expect(row.cells[1].tone, CellTone.good);
    });

    test('the official section still renders when no record was found', () {
      // Dashes, not a vanished section: the buyer has to be able to tell
      // "checked, nothing on file" from "we never looked".
      final sections = buildComparison(
        [car(id: 'a'), car(id: 'b')],
        gov: const [null, null],
      );
      final official =
          sections.firstWhere((s) => s.id == CompareSectionId.official);
      expect(official.rows, isNotEmpty);
      expect(rowNamed(sections, 'שינוי מבנה').cells[0].text, '—');
    });

    test('leasing and rental ownership is flagged, private is reassuring', () {
      final sections = buildComparison(
        [car(id: 'a'), car(id: 'b')],
        gov: [gov(ownershipType: 'ליסינג'), gov(ownershipType: 'פרטי')],
      );
      final row = rowNamed(sections, 'בעלות');
      expect(row.cells[0].tone, CellTone.bad);
      expect(row.cells[1].tone, CellTone.good);
    });
  });

  group('no overall verdict', () {
    test('nothing in the table totals, scores or ranks the cars', () {
      // Guard against a future "winner" row creeping in. A single number
      // weighing price against accident history is a claim the app has always
      // refused to make.
      final sections = buildComparison(
        [car(id: 'a'), car(id: 'b')],
        gov: [gov(), gov()],
      );
      final labels = sections.expand((s) => s.rows).map((r) => r.label);
      for (final banned in ['ציון', 'סה"כ', 'מנצח', 'המלצה', 'דירוג']) {
        expect(labels, isNot(contains(banned)));
      }
    });
  });

  group('picking cars', () {
    test('the third car is the last one accepted', () {
      final sel = CompareSelection();
      expect(sel.toggle(car(id: 'a')), isTrue);
      expect(sel.toggle(car(id: 'b')), isTrue);
      expect(sel.toggle(car(id: 'c')), isTrue);
      // Four columns do not fit a phone at a readable size.
      expect(sel.toggle(car(id: 'd')), isFalse);
      expect(sel.state, hasLength(maxCompareCars));
    });

    test('tapping a picked car unpicks it, and the order is kept', () {
      final sel = CompareSelection();
      sel.toggle(car(id: 'a'));
      sel.toggle(car(id: 'b'));
      sel.toggle(car(id: 'a'));
      expect(sel.state.map((c) => c.id), ['b']);
      sel.toggle(car(id: 'c'));
      expect(sel.state.map((c) => c.id), ['b', 'c']);
    });

    test('a full selection can still be changed by removing one', () {
      final sel = CompareSelection();
      for (final id in ['a', 'b', 'c']) {
        sel.toggle(car(id: id));
      }
      sel.remove('b');
      expect(sel.toggle(car(id: 'd')), isTrue);
      expect(sel.state.map((c) => c.id), ['a', 'c', 'd']);
    });
  });
}
