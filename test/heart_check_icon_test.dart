// The saved mark is painted rather than a font glyph, so nothing catches a
// broken path at compile time. These check that it lays out at the size asked
// for in both states and paints without throwing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:otov/presentation/widgets/heart_check_icon.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: child))),
  );
}

void main() {
  testWidgets('takes exactly the size it is given', (tester) async {
    await _pump(tester, const HeartCheckIcon(size: 40));
    expect(tester.getSize(find.byType(HeartCheckIcon)), const Size(40, 40));
  });

  testWidgets('paints filled and outlined without throwing', (tester) async {
    for (final filled in [true, false]) {
      await _pump(tester, HeartCheckIcon(size: 22, filled: filled));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('survives the sizes it is actually used at', (tester) async {
    // Tab bar, card button, action bar, empty state.
    for (final size in [20.0, 22.0, 24.0, 40.0, 64.0]) {
      await _pump(tester, HeartCheckIcon(size: size));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('the tab-bar form flips fill with selection', (tester) async {
    await _pump(
      tester,
      Row(children: [
        savedTabIcon(true, Colors.white, Colors.green),
        savedTabIcon(false, Colors.grey, Colors.white),
      ]),
    );

    final icons = tester
        .widgetList<HeartCheckIcon>(find.byType(HeartCheckIcon))
        .toList();
    expect(icons.first.filled, isTrue);
    expect(icons.last.filled, isFalse);
    expect(tester.takeException(), isNull);
  });
}
