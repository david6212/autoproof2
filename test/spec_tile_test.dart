import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/presentation/widgets/spec_tile.dart';

/// The spec tiles replaced a wash of brand green filled with rounded pills.
/// The pills showed values without naming the fields — "בנזין" and "כסף מטלי"
/// side by side, with nothing saying which was fuel and which was colour.
///
/// Two tiles to a row on a phone is tight, and it is tighter in Hebrew than the
/// mockup's English. These measure that it holds.
void main() {
  Widget host(Widget child, {double width = 390, double textScale = 1.0}) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: SingleChildScrollView(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<SpecTile> tiles(int n) => [
        for (var i = 0; i < n; i++)
          SpecTile(
              icon: Icons.settings_outlined,
              label: 'תיבת הילוכים $i',
              value: 'אוטומטית'),
      ];

  testWidgets('two tiles to a row, at equal height', (t) async {
    await t.pumpWidget(host(SpecTileGrid(tiles: tiles(4))));
    expect(t.takeException(), isNull);

    final rects = find
        .byType(SpecTile)
        .evaluate()
        .map((e) => t.getRect(find.byWidget(e.widget)))
        .toList();
    expect(rects, hasLength(4));

    // Pair 1 shares a top, pair 2 shares a lower one.
    expect(rects[0].top, closeTo(rects[1].top, 0.5));
    expect(rects[2].top, greaterThan(rects[0].top));
    // Equal height within a row — a short value must not leave a stubby tile
    // beside a tall one.
    expect(rects[0].height, closeTo(rects[1].height, 0.5));
  });

  testWidgets('an odd count leaves a gap, it does not stretch one tile',
      (t) async {
    // A lone tile stretched to full width reads as a heading, not as one of a
    // pair — and half the specs would look more important than the other half.
    await t.pumpWidget(host(SpecTileGrid(tiles: tiles(3))));
    expect(t.takeException(), isNull);

    final rects = find
        .byType(SpecTile)
        .evaluate()
        .map((e) => t.getRect(find.byWidget(e.widget)))
        .toList();
    expect(rects[2].width, closeTo(rects[0].width, 0.5));
  });

  testWidgets('a long Hebrew value does not overflow a narrow tile',
      (t) async {
    await t.pumpWidget(host(
      const SpecTileGrid(tiles: [
        SpecTile(
            icon: Icons.palette_outlined,
            label: 'צבע',
            value: 'כסף מטאלי בהיר במיוחד'),
        SpecTile(
            icon: Icons.badge_outlined,
            label: 'בעלות',
            value: 'ליסינג פרטי / השכרה'),
      ]),
      width: 320,
    ));
    expect(t.takeException(), isNull);
  });

  testWidgets('the grid survives the largest text scale', (t) async {
    for (final scale in [1.0, 1.3, 1.6]) {
      await t.pumpWidget(
          host(SpecTileGrid(tiles: tiles(6)), width: 320, textScale: scale));
      expect(t.takeException(), isNull, reason: 'text scale $scale');
    }
  });

  group('RecordRow', () {
    testWidgets('a chevron appears only when the row goes somewhere',
        (t) async {
      await t.pumpWidget(host(const RecordRow(
        icon: Icons.assignment_outlined,
        label: 'היסטוריית רכב רשמית',
        value: 'ק"מ בטסט, טסט, בעלויות וריקולים',
      )));
      expect(find.byIcon(Icons.chevron_left), findsNothing);

      await t.pumpWidget(host(RecordRow(
        icon: Icons.assignment_outlined,
        label: 'היסטוריית רכב רשמית',
        value: 'ק"מ בטסט, טסט, בעלויות וריקולים',
        onTap: () {},
      )));
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    });

    testWidgets('the tone is carried by the disc, not by the text', (t) async {
      // A record's text is a fact and stays readable ink. Only the status disc
      // colours, so a red row cannot make the value itself hard to read.
      for (final tone in RecordTone.values) {
        await t.pumpWidget(host(RecordRow(
          icon: Icons.check,
          label: 'שינוי מבני',
          value: 'לא רשום',
          tone: tone,
        )));
        expect(t.takeException(), isNull, reason: '$tone');
        final value = t.widget<Text>(find.text('לא רשום'));
        expect(value.style?.color, isNot(Colors.red), reason: '$tone');
      }
    });

    testWidgets('a long label is ellipsised, not overflowed', (t) async {
      await t.pumpWidget(host(
        RecordRow(
          icon: Icons.assignment_outlined,
          label: 'היסטוריית רכב רשמית מלאה ממשרד התחבורה',
          value: 'ק"מ בטסט האחרון, תוקף טסט, בעלויות קודמות וריקולים פתוחים',
          onTap: () {},
        ),
        width: 320,
      ));
      expect(t.takeException(), isNull);
    });
  });
}
