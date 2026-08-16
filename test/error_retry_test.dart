import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/presentation/widgets/error_retry.dart';

/// Seven of the eight error branches in the passport screens used to be dead
/// ends: they said the data would not load and offered nothing to do about it.
///
/// Most of those failures are a lost second of signal in a lift or a car park
/// and fix themselves on the next attempt — but only if there is an attempt.
/// These pin that the button exists and that the wording does not blame the
/// reader for a network they do not control.
void main() {
  Widget host(Widget child, {double width = 390, double textScale = 1.0}) =>
      MaterialApp(
        theme: AppTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: SizedBox(width: width, child: child),
            ),
          ),
        ),
      );

  testWidgets('an error always comes with a way out', (tester) async {
    var retried = 0;
    await tester.pumpWidget(host(ErrorRetry(
      message: 'לא הצלחנו לטעון את הרכבים',
      onRetry: () => retried++,
    )));

    expect(find.text('לא הצלחנו לטעון את הרכבים'), findsOneWidget);
    expect(find.text('נסו שוב'), findsOneWidget);

    await tester.tap(find.text('נסו שוב'));
    await tester.pump();
    expect(retried, 1);
  });

  testWidgets('the compact form still offers the retry', (tester) async {
    // Used inside the passport tabs, where a full-height block would push the
    // tab bar out of the reader's attention.
    await tester.pumpWidget(host(ErrorRetry(
      compact: true,
      message: 'לא הצלחנו לטעון את הטיפולים',
      onRetry: () {},
    )));
    expect(find.text('נסו שוב'), findsOneWidget);
  });

  testWidgets('it fits a narrow phone at the largest text scale',
      (tester) async {
    await tester.pumpWidget(host(
      ErrorRetry(
        message: 'לא הצלחנו לטעון את המסמכים',
        onRetry: () {},
      ),
      width: 320,
      textScale: 1.5,
    ));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the retry can be pressed more than once', (tester) async {
    // A first retry that also fails must not leave the reader stuck again —
    // the button stays live rather than disabling itself after one go.
    var retried = 0;
    await tester.pumpWidget(host(ErrorRetry(
      message: 'לא הצלחנו לטעון את הרשימה',
      onRetry: () => retried++,
    )));

    await tester.tap(find.text('נסו שוב'));
    await tester.pump();
    await tester.tap(find.text('נסו שוב'));
    await tester.pump();
    expect(retried, 2);
  });
}
