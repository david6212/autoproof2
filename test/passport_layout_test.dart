import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/presentation/widgets/spec_tile.dart';

/// The passport screens were written with a hand-rolled `Wrap` of
/// `SizedBox(width: 150)` tiles. That looked fine on the machine it was
/// written on and breaks in two places nobody was checking: a narrow phone,
/// and a reader who has turned the system font up.
///
/// `SpecTileGrid` already existed and already solved it. These pin that the
/// passport uses it rather than reinventing it — an overflow here paints the
/// yellow-and-black stripes on a real device, which is exactly where nobody
/// is looking.
void main() {
  Widget host(Widget child, {double width = 390, double textScale = 1.0}) =>
      MaterialApp(
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

  /// The exact tiles the passport overview shows for a real car.
  List<SpecTile> passportTiles() => const [
        SpecTile(
            icon: Icons.speed_outlined,
            label: 'קילומטראז\'',
            value: '92,000 ק"מ'),
        SpecTile(
            icon: Icons.local_gas_station_outlined,
            label: 'סוג דלק',
            value: 'בנזין'),
        SpecTile(
            icon: Icons.palette_outlined, label: 'צבע', value: 'אפור מטלי'),
        SpecTile(
            icon: Icons.tune, label: 'רמת גימור', value: 'EXECUTIVE 4X4'),
      ];

  testWidgets('the overview specs fit a narrow phone', (tester) async {
    await tester.pumpWidget(host(SpecTileGrid(tiles: passportTiles()),
        width: 320));
    expect(tester.takeException(), isNull);
  });

  testWidgets('and still fit at the largest text scale the app supports',
      (tester) async {
    // 1.5 is where the existing card tests draw the line, so the passport is
    // held to the same standard as the rest of the app.
    await tester.pumpWidget(host(
      SpecTileGrid(tiles: passportTiles()),
      width: 320,
      textScale: 1.5,
    ));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tiles pair up two to a row, at equal height', (tester) async {
    await tester.pumpWidget(host(SpecTileGrid(tiles: passportTiles())));

    final rects = find
        .byType(SpecTile)
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)))
        .toList();

    expect(rects, hasLength(4));
    expect(rects[0].top, closeTo(rects[1].top, 0.5));
    // Equal height within a row — "בנזין" must not leave a stubby tile beside
    // "EXECUTIVE 4X4". The fixed-width Wrap could not do this.
    expect(rects[0].height, closeTo(rects[1].height, 0.5));
    expect(rects[2].top, greaterThan(rects[0].top));
  });

  testWidgets('an odd count does not stretch the last tile', (tester) async {
    // A lone full-width tile reads as a heading, which would make half the
    // specs look more important than the other half.
    await tester.pumpWidget(host(
      SpecTileGrid(tiles: passportTiles().take(3).toList()),
    ));

    final rects = find
        .byType(SpecTile)
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)))
        .toList();

    expect(rects, hasLength(3));
    expect(rects[2].width, closeTo(rects[0].width, 0.5));
  });

  testWidgets('a single spec still occupies half the row', (tester) async {
    // The add-vehicle screen shows one tile when the registry returns only a
    // fuel type.
    await tester.pumpWidget(host(
      SpecTileGrid(tiles: passportTiles().take(1).toList()),
    ));
    expect(tester.takeException(), isNull);

    final row = tester.getSize(find.byType(SpecTileGrid));
    final tile = tester.getSize(find.byType(SpecTile));
    expect(tile.width, lessThan(row.width));
  });
}
