/// Builds the side-by-side comparison table for two or three listings.
///
/// This is deliberately pure: it takes listings (and their official records
/// when they have loaded) and returns rows of text. No widget, no provider —
/// so the thing that decides what "better" means is testable on its own.
///
/// **There is no overall score and no winner.** A cheaper car with three
/// previous owners is not "the better car", and a single number pretending to
/// weigh price against accident history would be a claim the app cannot stand
/// behind. Each row marks its own advantage; the judgement stays with the buyer.
library;

import 'package:intl/intl.dart';

import '../../data/models/car_model.dart';
import '../../data/models/gov_data_model.dart';
import 'date_formatter.dart';

/// Which direction counts as an advantage in a row, if any.
enum Advantage {
  /// Lower wins: price, km, previous owners, open recalls.
  lower,

  /// Higher wins: year of manufacture.
  higher,

  /// Not a competition — colour, drivetrain, seller type, body type.
  ///
  /// Spec rows use this on purpose. A bigger engine is not better for a buyer
  /// watching fuel costs, and marking one would smuggle in a preference the
  /// buyer never stated.
  none,
}

/// How a single cell reads on its own terms, independent of the other columns.
enum CellTone {
  neutral,

  /// Reassuring on its own: no open recalls, no structural change.
  good,

  /// A warning on its own: an expired licence, a recorded structural change.
  /// Coloured even when it is the only column with a value.
  bad,
}

class CompareCell {
  const CompareCell(this.text, {this.rank, this.tone = CellTone.neutral});

  final String text;

  /// The numeric value behind [text], used to pick the row's advantage.
  /// Null means unknown — an unknown never wins and never loses.
  final double? rank;

  final CellTone tone;

  /// A value the listing does not carry. Shown as a dash rather than left
  /// blank, so a missing field reads as "not reported" instead of as zero.
  static const unknown = CompareCell('—');

  bool get isKnown => text != '—';
}

class CompareRow {
  CompareRow._(this.label, this.cells, this.advantage, this.best);

  factory CompareRow({
    required String label,
    required List<CompareCell> cells,
    Advantage advantage = Advantage.none,
  }) {
    return CompareRow._(label, cells, advantage, _pickBest(cells, advantage));
  }

  final String label;
  final List<CompareCell> cells;
  final Advantage advantage;

  /// Column indexes holding this row's best value. Empty when the row is not a
  /// competition, when fewer than two columns know the value, or when every
  /// known value is equal — a tie is not an advantage, and marking all three
  /// columns with a tick would tell the buyer nothing.
  final Set<int> best;

  /// True when no column reported anything, so the row can be dropped.
  bool get isEmpty => cells.every((c) => !c.isKnown);

  static Set<int> _pickBest(List<CompareCell> cells, Advantage advantage) {
    if (advantage == Advantage.none) return const {};

    final known = <int, double>{};
    for (var i = 0; i < cells.length; i++) {
      final r = cells[i].rank;
      if (r != null) known[i] = r;
    }
    if (known.length < 2) return const {};

    final values = known.values.toSet();
    if (values.length == 1) return const {};

    final target = advantage == Advantage.lower
        ? values.reduce((a, b) => a < b ? a : b)
        : values.reduce((a, b) => a > b ? a : b);

    return known.entries
        .where((e) => e.value == target)
        .map((e) => e.key)
        .toSet();
  }
}

/// A titled group of rows. The screen decides the icon; this only names it.
class CompareSection {
  const CompareSection(this.id, this.title, this.rows, {this.note});

  final CompareSectionId id;
  final String title;
  final List<CompareRow> rows;

  /// Short line under the title, e.g. what the source is.
  final String? note;

  bool get isEmpty => rows.isEmpty;
}

enum CompareSectionId { listing, spec, official }

/// The Israeli average is roughly 15,000 km a year; these are the bands the
/// car page already uses, kept identical so the same car reads the same way in
/// both places.
const int kmPerYearLow = 12000;
const int kmPerYearHigh = 18000;

/// Maximum columns. Three is what fits a phone at a readable size, and a buyer
/// choosing between more than three has not shortlisted yet.
const int maxCompareCars = 3;

final _num = NumberFormat('#,###', 'en');

String _money(double v) => '₪${_num.format(v.round())}';

/// Average km per year, the figure the car page shows as a value signal.
int kmPerYear(CarModel car) {
  final age = DateTime.now().year - car.year;
  return age <= 0 ? car.km : (car.km / age).round();
}

/// Builds the whole table.
///
/// [gov] is positional to the cars: `gov[i]` is the official record for
/// `cars[i]`, or null when it has not loaded, failed, or the plate is not in
/// the registry. The official section still renders in that case, with dashes,
/// rather than disappearing and leaving the buyer unsure whether it was checked.
List<CompareSection> buildComparison(
  List<CarModel> cars, {
  List<GovData?> gov = const [],
}) {
  GovData? govFor(int i) => i < gov.length ? gov[i] : null;

  List<CompareCell> cells(CompareCell Function(int i, CarModel c) build) =>
      [for (var i = 0; i < cars.length; i++) build(i, cars[i])];

  return [
    CompareSection(
      CompareSectionId.listing,
      'המודעה',
      [
        CompareRow(
          label: 'מחיר',
          advantage: Advantage.lower,
          cells: cells((_, c) => CompareCell(_money(c.price), rank: c.price)),
        ),
        CompareRow(
          label: 'שנת ייצור',
          advantage: Advantage.higher,
          cells: cells((_, c) => c.year > 0
              ? CompareCell('${c.year}', rank: c.year.toDouble())
              : CompareCell.unknown),
        ),
        CompareRow(
          label: 'קילומטראז\'',
          advantage: Advantage.lower,
          cells: cells((_, c) =>
              CompareCell(_num.format(c.km), rank: c.km.toDouble())),
        ),
        CompareRow(
          label: 'ק"מ בשנה',
          advantage: Advantage.lower,
          cells: cells((_, c) {
            final v = kmPerYear(c);
            return CompareCell(
              _num.format(v),
              rank: v.toDouble(),
              tone: v < kmPerYearLow
                  ? CellTone.good
                  : v > kmPerYearHigh
                      ? CellTone.bad
                      : CellTone.neutral,
            );
          }),
        ),
        CompareRow(
          label: 'יד',
          advantage: Advantage.lower,
          cells: cells((_, c) =>
              CompareCell('יד ${c.hand}', rank: c.hand.toDouble())),
        ),
        CompareRow(
          label: 'אזור',
          cells: cells((_, c) => _text(c.area)),
        ),
        CompareRow(
          // No advantage: the app classifies sellers, it does not rank them.
          // A dealer is not a worse listing, only a differently labelled one.
          label: 'סוג מוכר',
          cells: cells((_, c) => CompareCell(c.sellerType.label)),
        ),
      ],
    ),
    CompareSection(
      CompareSectionId.spec,
      'מפרט הדגם',
      note: 'מתוך מאגר הדגמים של משרד התחבורה — נתוני הדגם, לא הרכב הספציפי',
      [
        CompareRow(
          label: 'נפח מנוע',
          cells: cells((_, c) {
            final cc = c.spec?.engineCc;
            // Electric models have no capacity at all. Saying "לא דווח" would
            // read as missing data; it is simply not a property they have.
            if (cc == null) {
              return c.fuelCategory == 'חשמלי'
                  ? const CompareCell('אין (חשמלי)')
                  : CompareCell.unknown;
            }
            return CompareCell('$cc סמ"ק');
          }),
        ),
        CompareRow(
          label: 'כוח סוס',
          cells: cells((_, c) {
            final hp = c.spec?.horsepower;
            return hp == null ? CompareCell.unknown : CompareCell('$hp כ"ס');
          }),
        ),
        CompareRow(
          label: 'תיבת הילוכים',
          cells: cells((_, c) {
            final s = c.spec;
            return s == null
                ? CompareCell.unknown
                : CompareCell(s.automatic ? 'אוטומטית' : 'ידנית');
          }),
        ),
        CompareRow(
          label: 'הנעה',
          cells: cells((_, c) => _text(c.spec?.drivetrain ?? '')),
        ),
        CompareRow(
          label: 'מושבים',
          cells: cells((_, c) {
            final n = c.spec?.seats;
            return n == null ? CompareCell.unknown : CompareCell('$n');
          }),
        ),
        CompareRow(
          label: 'דלתות',
          cells: cells((_, c) {
            final n = c.spec?.doors;
            return n == null ? CompareCell.unknown : CompareCell('$n');
          }),
        ),
        CompareRow(
          label: 'מרכב',
          cells: cells((_, c) => _text(c.spec?.bodyType ?? '')),
        ),
        CompareRow(
          label: 'סוג דלק',
          cells: cells((_, c) => _text(c.fuel)),
        ),
        CompareRow(
          label: 'צבע',
          cells: cells((_, c) => _text(c.color)),
        ),
      ],
    ),
    CompareSection(
      CompareSectionId.official,
      'רשומות משרד התחבורה',
      note: 'נשלף בזמן אמת לפי מספר הרישוי',
      [
        CompareRow(
          label: 'בעלות',
          cells: cells((i, c) {
            final o = govFor(i)?.ownershipType ?? c.ownership;
            if (o.trim().isEmpty) return CompareCell.unknown;
            // Private ownership is the reassuring case; leasing, rental and
            // driving-school histories are the ones a buyer asks about.
            return CompareCell(o,
                tone: o.contains('פרטי') ? CellTone.good : CellTone.bad);
          }),
        ),
        CompareRow(
          label: 'מקוריות',
          cells: cells((i, _) => _text(govFor(i)?.originality ?? '')),
        ),
        CompareRow(
          label: 'ק"מ בטסט האחרון',
          cells: cells((i, _) {
            final km = govFor(i)?.lastTestKm;
            return (km == null || km <= 0)
                ? CompareCell.unknown
                : CompareCell(_num.format(km));
          }),
        ),
        CompareRow(
          label: 'התאמת ק"מ',
          cells: cells((i, c) {
            final official = govFor(i)?.lastTestKm;
            if (official == null || official <= 0) return CompareCell.unknown;
            // The listing showing FEWER km than the last official test is the
            // rollback signal. The reverse is normal — the car kept driving
            // after the test.
            if (c.km < official) {
              return CompareCell('נמוך ב-${_num.format(official - c.km)}',
                  tone: CellTone.bad);
            }
            return const CompareCell('תואם', tone: CellTone.good);
          }),
        ),
        CompareRow(
          label: 'תוקף רישיון',
          cells: cells((i, _) {
            final d = govFor(i)?.licenseExpiry;
            if (d == null) return CompareCell.unknown;
            final expired = d.isBefore(DateTime.now());
            return CompareCell(DateFormatter.format(d),
                tone: expired ? CellTone.bad : CellTone.good);
          }),
        ),
        CompareRow(
          label: 'שינוי מבנה',
          cells: cells((i, _) {
            final g = govFor(i);
            if (g == null) return CompareCell.unknown;
            return g.structuralChange
                ? const CompareCell('נרשם', tone: CellTone.bad)
                : const CompareCell('לא נרשם', tone: CellTone.good);
          }),
        ),
        CompareRow(
          label: 'ריקולים פתוחים',
          advantage: Advantage.lower,
          cells: cells((i, _) {
            final g = govFor(i);
            if (g == null) return CompareCell.unknown;
            final n = g.recalls.length;
            return CompareCell(
              n == 0 ? 'אין' : '$n',
              rank: n.toDouble(),
              tone: n == 0 ? CellTone.good : CellTone.bad,
            );
          }),
        ),
        CompareRow(
          label: 'ירידה מהכביש',
          cells: cells((i, _) {
            final g = govFor(i);
            if (g == null) return CompareCell.unknown;
            return g.offRoad
                ? const CompareCell('כן', tone: CellTone.bad)
                : const CompareCell('לא', tone: CellTone.good);
          }),
        ),
        CompareRow(
          label: 'עלה לכביש',
          cells: cells((i, _) {
            final s = govFor(i)?.firstOnRoadDisplay ?? '';
            return _text(s == '—' ? '' : s);
          }),
        ),
      ],
    ),
  ];
}

CompareCell _text(String v) =>
    v.trim().isEmpty ? CompareCell.unknown : CompareCell(v.trim());
