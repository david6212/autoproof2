import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/core/theme/app_palette.dart';
import 'package:bonnetcheck/presentation/widgets/app_bar_action.dart';

/// The comparison button shipped green-on-green: a plain `TextButton` in an
/// app bar takes `colorScheme.primary` from Material's own defaults, which in
/// this app is the brand green, and the app bar's background is that same green
/// 6% darker. The label measured about 1.2:1 — present, tappable, unreadable —
/// and the user spotted it from a screenshot.
///
/// Nothing in the analyzer, the type scale or the palette tests could have
/// caught that: every colour involved is a legitimate token, just not against
/// each other.
double ratio(Color a, Color b) {
  final (x, y) = (a.computeLuminance(), b.computeLuminance());
  final (hi, lo) = x > y ? (x, y) : (y, x);
  return (hi + 0.05) / (lo + 0.05);
}

/// `TextButton.icon` returns a private SUBCLASS of TextButton, and
/// `find.byType` matches the exact runtime type — so the icon variant is
/// invisible to it. This finds both forms.
Finder theButton() => find.byWidgetPredicate((w) => w is TextButton);

void main() {
  Widget host(ThemeData theme, {IconData? icon}) => MaterialApp(
        theme: theme,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('רכבים שמורים'),
              actions: [
                AppBarAction(label: 'השוואה', icon: icon, onPressed: () {}),
              ],
            ),
          ),
        ),
      );

  testWidgets('the label is legible on the app bar, in both themes', (t) async {
    for (final (name, theme, palette) in [
      ('light', AppTheme.light, AppPalette.light),
      ('dark', AppTheme.dark, AppPalette.dark),
    ]) {
      await t.pumpWidget(host(theme));

      final button = t.widget<TextButton>(theButton());
      final fg = button.style!.foregroundColor!.resolve({});

      expect(fg, palette.onBrand, reason: '$name: must use the on-brand ink');
      // The app bar's own background is what it has to carry against.
      expect(ratio(fg!, palette.tealFill), greaterThan(4.5),
          reason: '$name: label on the app bar');
    }
  });

  testWidgets('it is never the brand green, which is what broke', (t) async {
    await t.pumpWidget(host(AppTheme.light));
    final button = t.widget<TextButton>(theButton());
    final fg = button.style!.foregroundColor!.resolve({});

    for (final p in [AppPalette.light, AppPalette.dark]) {
      expect(fg, isNot(p.teal));
      expect(fg, isNot(p.tealFill));
      expect(fg, isNot(p.tealText));
    }
  });

  testWidgets('a plain TextButton in an app bar really is unreadable', (t) async {
    // Pins the reason this widget exists. If a future Material version stops
    // defaulting to colorScheme.primary here, this test fails and the widget
    // can be reconsidered — rather than being cargo-culted forever.
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        appBar: AppBar(
          actions: [TextButton(onPressed: () {}, child: const Text('השוואה'))],
        ),
      ),
    ));

    final ctx = t.element(theButton());
    final fallback = Theme.of(ctx).colorScheme.primary;
    expect(ratio(fallback, AppPalette.light.tealFill), lessThan(3.0),
        reason: 'the unstyled default is the trap this widget avoids');
  });

  testWidgets('the tap target clears 48px with and without an icon', (t) async {
    for (final icon in [null, Icons.compare_arrows]) {
      await t.pumpWidget(host(AppTheme.light, icon: icon));
      final size = t.getSize(theButton());
      expect(size.height, greaterThanOrEqualTo(48), reason: 'icon: $icon');
      expect(size.width, greaterThanOrEqualTo(48), reason: 'icon: $icon');
    }
  });
}
