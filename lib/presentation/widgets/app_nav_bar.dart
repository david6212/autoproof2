import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';

/// One destination in [AppNavBar].
class NavTab {
  const NavTab(this.path, this.icon, this.activeIcon, this.label,
      {this.iconBuilder});

  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// Draws the icon instead of [icon]/[activeIcon], for a tab whose mark is
  /// not a Material glyph. Gets the pill's foreground and background so it
  /// can match either state.
  final Widget Function(bool selected, Color fg, Color bg)? iconBuilder;
}

/// The app's bottom navigation: a flat bar on the page's own surface, with a
/// hairline above it and every destination named.
///
/// It used to be a floating pill where **only the selected tab showed its
/// label**, because five Hebrew labels laid out beside their icons do not fit a
/// narrow phone. Stacking each label under its icon at 10.5px removes that
/// constraint — five labels fit a 320px screen with room to spare — so every
/// destination can say what it is instead of three of five being a bare glyph.
///
/// Shared by the buyer and seller shells so the two can't drift apart.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<NavTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpace.sm + 1),
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                // Equal shares, so the bar does not shuffle sideways when the
                // selected tab changes and its label changes width.
                Expanded(
                  child: _NavItem(
                    tab: tabs[i],
                    selected: i == currentIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final NavTab tab;
  final bool selected;
  final VoidCallback onTap;

  /// Label size. Small, because five of them share a phone's width — but not
  /// so small that it stops being text a person reads.
  static const _labelSize = 10.5;

  @override
  Widget build(BuildContext context) {
    // `tealText2`, NOT `tealFill`. The reference design names its deep green
    // for the active tab, and reaching for our equivalent fill token measured
    // **2.6:1 on the dark surface** — the selected tab was nearly invisible in
    // dark mode. The fill green is a colour to put white ON; a label is ink,
    // and green ink on a surface is what `tealText2` exists for: 6.74:1 light,
    // 7.97:1 dark.
    //
    // Inactive is `textMuted` (6.14 / 7.12). The reference used its lightest
    // grey there, about 2.5 — fine as a mood, not as a label a person has to
    // read to know where they are.
    final fg =
        selected ? context.colors.tealText2 : context.colors.textMuted;

    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tab.iconBuilder?.call(selected, fg, context.colors.surface) ??
                  Icon(selected ? tab.activeIcon : tab.icon,
                      size: 22, color: fg),
              const SizedBox(height: AppSpace.xs - 1),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(
                  color: fg,
                  fontSize: _labelSize,
                  // Weight carries the state as well as colour does. The fuel
                  // tab deliberately uses the SAME glyph in both states (its
                  // outlined codepoint caused an invisible-icon bug), so it has
                  // no filled/outlined cue — without this, colour alone would
                  // be the only signal on that one tab.
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
