import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/core/theme/app_palette.dart';
import 'package:bonnetcheck/data/models/gov_data_model.dart';
import 'package:bonnetcheck/presentation/widgets/share_check_result.dart';

/// Forwarding a check result.
///
/// A WhatsApp message outlives the screen it came from: it arrives with no
/// source banner above it, no disclaimer under it and no way to ask where the
/// numbers came from. So everything the screen says around the figures has to
/// travel inside the text — and the one field that identifies a car and its
/// keeper has to stay out of it unless the sender says otherwise.
void main() {
  /// Built the way the app builds one: parsed from the registry's own field
  /// names, then enriched. Constructing `GovData` by hand in a test drifts
  /// from what the parser actually produces.
  GovData car({
    bool offRoad = false,
    List<RecallItem> recalls = const [],
    Set<GovDataset> missing = const {},
    bool colorChanged = false,
  }) {
    final base = GovData.fromApi({
      'mispar_rechev': 12345678,
      'tozeret_nm': 'מאזדה',
      'kinuy_mishari': 'CX-5',
      'degem_nm': 'CX-5',
      'shnat_yitzur': 2017,
      'tzeva_rechev': 'שחור',
      'sug_delek_nm': 'בנזין',
      'baalut': 'פרטי',
      'mivchan_acharon_dt': '2026-08-12',
      'tokef_dt': '2027-08-11',
      if (colorChanged) 'shnui_zeva_ind': 1,
    });

    return base.withExtras(
      history: const {'kilometer_test_aharon': 92000},
      recalls: recalls,
      offRoad: offRoad ? const {'bitul_dt': '2026-01-01'} : null,
      missing: missing,
    );
  }

  group('what goes out in the message', () {
    test('the car, the readings, and where they came from', () {
      final text = checkShareText(car(), checkedAt: DateTime(2026, 9, 27));

      expect(text, contains('מאזדה CX-5'));
      expect(text, contains('2017'));
      expect(text, contains('טסט אחרון: 12/08/2026'));
      expect(text, contains('92,000 ק"מ'));
      expect(text, contains('נבדק ב-27/09/2026'));
      expect(text, contains('data.gov.il'));
      expect(text, contains('bonnetcheck'));
    });

    test('and the limits, because the message travels without the screen', () {
      final text = checkShareText(car());
      expect(text, contains('אינו אישור רשמי'));
      expect(text, contains('אינו בדיקה של הרכב עצמו'));
      expect(text, contains('עשוי להיות חסר או לא מעודכן'));
    });

    test('a finding is included when there is one', () {
      final text = checkShareText(car(
        recalls: const [
          RecallItem(system: 'בלמים', description: 'ריקול', date: '2026-01-01'),
        ],
      ));
      expect(text, contains('קריאת שירות פתוחה אחת'));
    });

    test('but never when the dataset did not answer', () {
      // The rule the whole app turns on: silence from a server and a clean
      // register look identical, and only the record of which datasets
      // replied can tell them apart. A forwarded message must not turn the
      // first into the second.
      final text = checkShareText(car(missing: {GovDataset.recalls}));
      expect(text.contains('קריאות שירות'), isFalse);
      expect(text.contains('אין קריאות'), isFalse,
          reason: 'absence of an answer is not an answer of absence');
    });

    test('a scrapped car says so', () {
      expect(checkShareText(car(offRoad: true)), contains('מבוטל'));
    });
  });

  group('the plate', () {
    test('is absent by default', () {
      final text = checkShareText(car());
      expect(text.contains('12345678'), isFalse);
      expect(text.contains('מספר רישוי'), isFalse);
    });

    test('goes out only when the sender asked for it', () {
      final text = checkShareText(car(), plate: '12345678');
      expect(text, contains('מספר רישוי: 12345678'));
    });

    test('an empty plate is not a line with nothing after it', () {
      expect(checkShareText(car(), plate: '   ').contains('מספר רישוי'), isFalse);
    });
  });

  testWidgets('the switch is off when the card opens', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: const [AppPalette.light]),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: ShareCheckResult(data: car(), plate: '12345678'),
        ),
      ),
    ));

    final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.value, isFalse,
        reason: 'including the plate is a decision, and the safe side is the '
            'default');
    expect(find.textContaining('כבוי כברירת מחדל'), findsOneWidget);
  });

  test('analytics counts that a share happened, not what was in it', () {
    final analytics = File('lib/presentation/providers/analytics_provider.dart')
        .readAsStringSync();
    expect(analytics, contains('Future<void> checkShared() =>'));
    expect(analytics.contains('checkShared(String'), isFalse);
  });
}
