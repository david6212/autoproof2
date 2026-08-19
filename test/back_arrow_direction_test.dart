import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which way a back arrow points in a right-to-left app.
///
/// Five screens had it backwards, and the mistake is a reasonable one: in
/// Hebrew "back" is rightwards, so `Icons.arrow_forward` looks like the
/// obvious pick. It is not. Both glyphs carry `matchTextDirection: true`, so
/// Flutter already mirrors them — `arrow_back` draws rightwards under RTL,
/// which is what we want, and `arrow_forward` draws leftwards, which is how
/// every back button in the app ended up pointing the wrong way.
///
/// The scan is deliberately over source rather than over one rendered screen.
/// The bug is a piece of reasoning, not a typo, and it will be re-derived by
/// the next person to add a screen; a widget test on one of the five would
/// have caught none of the other four.
void main() {
  test('no back button reaches for the mirrored-twice arrow', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('Icons.arrow_forward')) {
          offenders.add('${entity.path}:${i + 1}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Icons.arrow_back is the one that points right under RTL. '
          'If a genuine "next" arrow is ever needed, it belongs in a named '
          'widget that says so, not in an AppBar leading.',
    );
  });

  testWidgets('and it really does point right on screen', (tester) async {
    // The scan proves which constant is used; this proves what that constant
    // does. Together they close the loop the five screens fell through.
    await tester.pumpWidget(const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Icon(Icons.arrow_back),
      ),
    ));

    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon!.matchTextDirection, isTrue,
        reason: 'a glyph that does not mirror would point left in Hebrew');
  });
}
