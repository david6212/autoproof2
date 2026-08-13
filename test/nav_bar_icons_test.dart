import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/theme.dart';
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

  testWidgets('only the selected tab shows a label', (t) async {
    // Five Hebrew words side by side do not fit a phone; the filled pill is
    // what says where you are.
    await t.pumpWidget(_bar(selected: 2));
    for (final tab in BuyerShell.tabs) {
      expect(find.text(tab.label),
          tab.path == '/fuel' ? findsOneWidget : findsNothing);
    }
  });
}
