import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/core/utils/release_error_widget.dart';

/// An app is allowed to break. It is not allowed to break silently.
///
/// Flutter's release-mode `ErrorWidget` is a grey rectangle carrying no text
/// at all. On 26/08 that cost a day: the fuel screen came back from a real
/// phone as "empty screen", and the two things that would have identified it
/// were both absent by design — no skeleton meant it was not loading, no
/// message meant the error branch was never reached. The framework knew the
/// exception and painted over it.
///
/// The person reporting a bug is usually the only one who can see it. What
/// they can send is a screenshot, so the screenshot has to be worth something.
void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('a broken widget names its exception on screen', (tester) async {
    final details = FlutterErrorDetails(
      exception: StateError('the thing that actually broke'),
      stack: StackTrace.fromString(
        '#0      FuelStationsScreen._map (package:bonnetcheck/x.dart:204)\n'
        '#1      _FuelStationsScreenState.build (package:bonnetcheck/x.dart:158)',
      ),
    );

    await tester.pumpWidget(host(ReleaseErrorWidget(details)));

    // The reader is told, in their own language, that this is one screen and
    // not the whole app.
    expect(find.text('משהו במסך הזה נשבר'), findsOneWidget);

    // And the part that makes a screenshot actionable.
    expect(
      find.textContaining('the thing that actually broke'),
      findsOneWidget,
      reason: 'a grey box with no text is what this exists to replace',
    );
    expect(find.textContaining('FuelStationsScreen._map'), findsOneWidget,
        reason: 'the first app frame is the one that identifies the fault');
  });

  testWidgets('it survives a failure that carries no stack', (tester) async {
    // An error widget that throws while reporting an error takes down the
    // whole app instead of one subtree.
    await tester.pumpWidget(host(const ReleaseErrorWidget(
      FlutterErrorDetails(exception: 'plain string, no stack'),
    )));

    expect(find.textContaining('plain string, no stack'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the stack is trimmed, not dumped', (tester) async {
    // Forty frames of framework internals push the useful line off a phone
    // screen, which defeats the point.
    final long = List.generate(40, (i) => '#$i      frame$i (package:f/f.dart)')
        .join('\n');
    await tester.pumpWidget(host(ReleaseErrorWidget(FlutterErrorDetails(
      exception: 'boom',
      stack: StackTrace.fromString(long),
    ))));

    expect(find.textContaining('frame0'), findsOneWidget);
    expect(find.textContaining('frame39'), findsNothing);
  });

  // A plain `test`, not `testWidgets`: the widget binding asserts that
  // `ErrorWidget.builder` is back to the framework's own by the time a widget
  // test's body returns, and restoring it in a tearDown runs too late.
  test('installing it replaces the framework default', () {
    final original = ErrorWidget.builder;
    try {
      ReleaseErrorWidget.install();
      expect(
        ErrorWidget.builder(const FlutterErrorDetails(exception: 'installed')),
        isA<ReleaseErrorWidget>(),
      );
    } finally {
      ErrorWidget.builder = original;
    }
  });
}
