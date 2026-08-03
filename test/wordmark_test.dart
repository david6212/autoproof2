// The wordmark gained entrance parameters for the splash. It is also on the
// login and About screens, where it must stay perfectly still — so the
// defaults are pinned here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:otov/presentation/widgets/otov_logo.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: child))),
  );
}

List<double> _translations(WidgetTester tester) => tester
    .widgetList<Transform>(find.byType(Transform))
    .map((t) => t.transform.getTranslation().x)
    .toList();

void main() {
  testWidgets('sits still by default', (tester) async {
    await _pump(tester, const OtovWordmark(fontSize: 30));

    for (final dx in _translations(tester)) {
      expect(dx, 0.0, reason: 'the static wordmark must not be offset');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('mid-entrance the two halves are apart', (tester) async {
    await _pump(tester, const OtovWordmark(fontSize: 30, entrance: 0.2));

    final dxs = _translations(tester).where((x) => x.abs() > 1).toList();
    expect(dxs.any((x) => x < 0), isTrue, reason: '"Oto" comes from the left');
    expect(dxs.any((x) => x > 0), isTrue, reason: 'the V comes from the right');
  });

  testWidgets('a bigger checkScale does not change the type size',
      (tester) async {
    await _pump(tester, const OtovWordmark(fontSize: 30));
    final plain = tester.getSize(find.text('Oto'));

    await _pump(tester, const OtovWordmark(fontSize: 30, checkScale: 1.4));
    expect(tester.getSize(find.text('Oto')), plain,
        reason: 'scaling the V must not resize the letters');
  });

  testWidgets('renders at every scale the app uses', (tester) async {
    for (final size in [30.0, 34.0, 44.0]) {
      await _pump(tester, OtovWordmark(fontSize: size));
      expect(tester.takeException(), isNull);
    }
  });
}
