import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/presentation/widgets/saved_check_icon.dart';

/// The saved mark used to be a heart with a check tucked inside it — two
/// shapes competing inside 20 logical pixels. It is now the brand's check on
/// its own, and state is carried by stroke weight plus the colour of whatever
/// container it sits in, never by adding a shape back.
Future<void> _pump(WidgetTester t, Widget child, {double scale = 1.0}) {
  return t.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  ));
}

void main() {
  testWidgets('takes exactly the size it is given', (t) async {
    await _pump(t, const SavedCheckIcon(size: 40));
    expect(t.getSize(find.byType(SavedCheckIcon)), const Size(40, 40));
  });

  testWidgets('renders at every size the app draws it at', (t) async {
    // 20 on the card button, 22 in the tab bar, 24 in profile, 40 and 64 in
    // the two empty states.
    for (final size in [20.0, 22.0, 24.0, 40.0, 64.0]) {
      await _pump(t, SavedCheckIcon(size: size));
      expect(t.takeException(), isNull, reason: 'size $size');
      expect(t.getSize(find.byType(SavedCheckIcon)), Size(size, size));
    }
  });

  testWidgets('both states paint without throwing', (t) async {
    for (final filled in [false, true]) {
      await _pump(t, SavedCheckIcon(size: 22, filled: filled));
      expect(t.takeException(), isNull, reason: 'filled=$filled');
    }
  });

  testWidgets('the icon does not scale with the text setting', (t) async {
    // It is a glyph in a fixed-size button, not type. If it grew with the text
    // scale it would burst the 40px circle on the card.
    await _pump(t, const SavedCheckIcon(size: 20), scale: 2.0);
    expect(t.getSize(find.byType(SavedCheckIcon)), const Size(20, 20));
  });

  testWidgets('the tab-bar form follows selection and takes the pill ink',
      (t) async {
    await _pump(
      t,
      Column(children: [
        savedTabIcon(true, Colors.white, Colors.green),
        savedTabIcon(false, Colors.grey, Colors.white),
      ]),
    );
    final icons =
        t.widgetList<SavedCheckIcon>(find.byType(SavedCheckIcon)).toList();
    expect(icons, hasLength(2));
    expect(icons[0].filled, isTrue);
    expect(icons[0].color, Colors.white);
    expect(icons[1].filled, isFalse);
    expect(icons[1].color, Colors.grey);
  });
}
