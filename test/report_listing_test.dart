// What a report stores is what a human later reads when deciding whether to
// pull a listing, so the composition is pinned rather than left to the widget.

import 'package:flutter_test/flutter_test.dart';

import 'package:otov/presentation/widgets/report_listing_sheet.dart';

void main() {
  group('reportNote', () {
    test('a reason on its own is enough', () {
      expect(reportNote(ReportReason.fraud, ''), ReportReason.fraud.label);
    });

    test('detail is appended to the reason, not instead of it', () {
      final note = reportNote(ReportReason.misleading, 'הק"מ לא תואם');
      expect(note, startsWith(ReportReason.misleading.label));
      expect(note, contains('הק"מ לא תואם'));
    });

    test('whitespace-only detail is treated as none', () {
      expect(reportNote(ReportReason.duplicate, '   \n  '),
          ReportReason.duplicate.label);
    });
  });

  group('the reasons offered', () {
    test('cover the grounds the removal policy promises', () {
      // The policy lists misleading details, a listing published without the
      // owner's permission, offensive content and personal data. A ground
      // with no matching option is a promise the app can't keep.
      expect(ReportReason.values, contains(ReportReason.misleading));
      expect(ReportReason.values, contains(ReportReason.notForSale));
      expect(ReportReason.values, contains(ReportReason.offensive));
      expect(ReportReason.values, contains(ReportReason.myDetails));
    });

    test('every reason has a label a person can read', () {
      for (final r in ReportReason.values) {
        expect(r.label.trim(), isNotEmpty);
        expect(r.label, isNot(r.name));
      }
    });
  });
}
