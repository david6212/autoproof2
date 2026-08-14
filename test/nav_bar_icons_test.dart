import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/core/theme/app_palette.dart';
import 'package:bonnetcheck/presentation/widgets/app_nav_bar.dart';
import 'package:bonnetcheck/presentation/widgets/buyer_shell.dart';
import 'package:bonnetcheck/presentation/widgets/saved_check_icon.dart';

/// Every tab has to draw *something*. A `NavTab` whose glyph does not render
/// leaves a live, tappable, invisible slot — the bar still spaces five items,
/// so the gap looks like a layout bug rather than a missing icon, and the tab
/// is unreachable by anyone who cannot guess it is there.
///
/// This bit once: swapping the discover tab for fuel reintroduced
/// `Icons.local_gas_station_outlined`, a codepoint that had been removed from
/// the tree-shaken icon font two commits earlier. The new code asked the
/// browser's cached font for a glyph that font did not contain, and the slot
/// came up blank. The build was correct; only the cache was stale. A test
/// cannot see a cached font — but it can hold the invariant that every tab
/// puts a mark on screen.
Widget _bar({int selected = 0}) => MaterialApp(
      theme: AppTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          bottomNavigationBar: AppNavBar(
            tabs: BuyerShell.tabs,
            currentIndex: selected,
            onSelected: (_) {},
          ),
        ),
      ),
    );

void main() {
  testWidgets('every tab paints a mark, in both of its states', (t) async {
    // Walk the selection so each tab is rendered selected once and unselected
    // otherwise — `activeIcon` is a separate codepoint and can go missing on
    // its own.
    for (var i = 0; i < BuyerShell.tabs.length; i++) {
      await t.pumpWidget(_bar(selected: i));
      expect(t.takeException(), isNull, reason: 'selected index $i');

      final marks = t.widgetList<Icon>(find.byType(Icon)).length +
          t.widgetList<SavedCheckIcon>(find.byType(SavedCheckIcon)).length;
      expect(marks, BuyerShell.tabs.length,
          reason: 'one tab drew nothing with index $i selected');
    }
  });

  testWidgets('the fuel tab carries a real glyph in both states', (t) async {
    final fuel = BuyerShell.tabs.firstWhere((x) => x.path == '/fuel');
    expect(fuel.icon.codePoint, isNot(0));
    expect(fuel.activeIcon.codePoint, isNot(0));
    expect(fuel.icon.fontFamily, 'MaterialIcons');

    await t.pumpWidget(_bar(selected: 2));
    expect(find.byIcon(fuel.activeIcon), findsOneWidget,
        reason: 'selected fuel tab should draw its active glyph');

    await t.pumpWidget(_bar(selected: 0));
    expect(find.byIcon(fuel.icon), findsOneWidget,
        reason: 'unselected fuel tab should draw its glyph');

    // Deliberately the same codepoint in both states — see the comment on the
    // tab. A second, rarely-used glyph is what made this tab invisible.
    expect(fuel.icon.codePoint, fuel.activeIcon.codePoint);
  });

  testWidgets('every tab is named, not just the selected one', (t) async {
    // It used to be only the selected one: five Hebrew words laid out BESIDE
    // their icons do not fit a phone. Stacked under them at 10.5px they do,
    // so three of five destinations no longer have to be a bare glyph.
    await t.pumpWidget(_bar(selected: 2));
    for (final tab in BuyerShell.tabs) {
      expect(find.text(tab.label), findsOneWidget, reason: tab.label);
    }
  });

  testWidgets('five labels fit a small phone without overflowing', (t) async {
    // 320px is the narrowest the app supports, and Hebrew labels are wider
    // than the reference design's English ones.
    await t.pumpWidget(MediaQuery(
      data: const MediaQueryData(size: Size(320, 640)),
      child: _bar(selected: 0),
    ));
    expect(t.takeException(), isNull);

    for (final tab in BuyerShell.tabs) {
      expect(find.text(tab.label), findsOneWidget, reason: tab.label);
    }
  });

  testWidgets('the state is carried by more than colour', (t) async {
    // The fuel tab uses the SAME glyph selected or not, so a filled/outlined
    // cue does not exist there. Weight has to do that job on every tab, or a
    // colour-blind user cannot tell which one they are on.
    await t.pumpWidget(_bar(selected: 2));

    final fuel = t.widget<Text>(find.text('דלק'));
    final home = t.widget<Text>(find.text('בית'));
    expect(fuel.style?.fontWeight, FontWeight.bold);
    expect(home.style?.fontWeight, isNot(FontWeight.bold));
    expect(fuel.style?.color, isNot(home.style?.color));
  });

  testWidgets('both label inks are readable on the bar, in both themes',
      (t) async {
    // This caught a real one. The reference design names its deep green for the
    // active tab, and our equivalent FILL token measures 2.6:1 on the dark
    // surface — the selected tab was nearly invisible in dark mode. A label is
    // ink, not a fill, so it takes the green-ink token.
    //
    // The reference also used its lightest grey for inactive tabs (~2.5:1). A
    // label you cannot read is not a smaller label, it is a missing one.
    double ratio(Color a, Color b) {
      final (x, y) = (a.computeLuminance(), b.computeLuminance());
      final (hi, lo) = x > y ? (x, y) : (y, x);
      return (hi + 0.05) / (lo + 0.05);
    }

    for (final p in [AppPalette.light, AppPalette.dark]) {
      expect(ratio(p.tealText2, p.surface), greaterThan(4.5),
          reason: 'selected label');
      expect(ratio(p.textMuted, p.surface), greaterThan(4.5),
          reason: 'unselected label');
    }

    // The trap itself, pinned. `tealFill` is fine on a white card (6.47) —
    // which is exactly why reaching for it looks right until someone opens the
    // app in dark mode. It is a colour to put white ON, and it fails as ink on
    // the one surface a light-mode developer never sees.
    expect(ratio(AppPalette.dark.tealFill, AppPalette.dark.surface),
        lessThan(3.0),
        reason: 'the fill green is not a label colour on a dark surface');
  });
}
