import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/core/theme/app_palette.dart';
import 'package:bonnetcheck/presentation/widgets/app_bar_action.dart';

/// The comparison button once shipped green-on-green: a plain `TextButton` in
/// an app bar takes `colorScheme.primary` from Material's own defaults — the
/// brand green — and the bar was then that same green slightly darker. The
/// label measured about 1.2:1: present, tappable, unreadable. The user spotted
/// it from a screenshot.
///
/// Nothing in the analyzer, the type scale or the palette tests could have
/// caught that: every colour involved is a legitimate token, just not against
/// each other.
///
/// The bar is now the page colour, which makes the same default 3.77:1 —
/// better, still under the floor. These tests hold the fix in place through
/// that change and the next one.
double ratio(Color a, Color b) {
  final (x, y) = (a.computeLuminance(), b.computeLuminance());
  final (hi, lo) = x > y ? (x, y) : (y, x);
  return (hi + 0.05) / (lo + 0.05);
}

/// `TextButton.icon` returns a private SUBCLASS of TextButton, and
/// `find.byType` matches the exact runtime type — so the icon variant is
/// invisible to it. This finds both forms.
Finder theButton() => find.byWidgetPredicate((w) => w is TextButton);

/// Pumps a theme and lets it actually arrive.
///
/// `MaterialApp` animates between themes (`AnimatedTheme`, 200ms). Pumping a
/// new theme and asserting immediately reads the OLD one — which in a
/// light-then-dark loop means every dark assertion silently tests the light
/// palette and passes or fails for the wrong reason.
Future<void> pumpTheme(WidgetTester t, Widget app) async {
  await t.pumpWidget(app);
  await t.pump(const Duration(milliseconds: 400));
}

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
      await pumpTheme(t, host(theme));

      final button = t.widget<TextButton>(theButton());
      final fg = button.style!.foregroundColor!.resolve({});

      expect(fg, palette.tealText2, reason: '$name: green ink on a light bar');
      // The bar is the page colour now, so that is what the label has to
      // carry against — NOT the old green fill.
      expect(ratio(fg!, palette.background), greaterThan(4.5),
          reason: '$name: label on the app bar');
    }
  });

  testWidgets('it is never the identity green, which is what broke', (t) async {
    // `teal` is the mark's colour. It measures 3.77:1 on the page — fine for a
    // graphic, under the floor for a label — and it is reserved for the emblem
    // regardless.
    await t.pumpWidget(host(AppTheme.light));
    final button = t.widget<TextButton>(theButton());
    final fg = button.style!.foregroundColor!.resolve({});

    for (final p in [AppPalette.light, AppPalette.dark]) {
      expect(fg, isNot(p.teal));
      expect(fg, isNot(p.tealFill));
    }
  });

  testWidgets('a plain TextButton in an app bar is still under the floor',
      (t) async {
    // Pins the reason this widget exists. The trap got milder when the bar
    // stopped being green — 1.2:1 became 3.77:1 — but it is still a label
    // below 4.5, which is exactly the sort of "looks fine" regression that
    // ships. If Material ever stops defaulting to colorScheme.primary here,
    // this fails and the widget can be reconsidered rather than cargo-culted.
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
    expect(ratio(fallback, AppPalette.light.background), lessThan(4.5),
        reason: 'the unstyled default is the trap this widget avoids');
  });

  testWidgets('the bar carries a hairline instead of a colour change',
      (t) async {
    // The bar and the page share a colour now. Without the border there is
    // nothing separating a title from the content scrolling under it.
    for (final (name, theme, palette) in [
      ('light', AppTheme.light, AppPalette.light),
      ('dark', AppTheme.dark, AppPalette.dark),
    ]) {
      await pumpTheme(t, host(theme));
      final bar = t.widget<AppBar>(find.byType(AppBar));
      final shape = (bar.shape ?? Theme.of(t.element(find.byType(AppBar)))
              .appBarTheme
              .shape) as Border?;
      expect(shape?.bottom.color, palette.cardBorder, reason: name);
    }
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
