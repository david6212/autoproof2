import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import 'glass.dart';

/// One destination in [AppNavBar].
class NavTab {
  const NavTab(
    this.path,
    this.icon,
    this.activeIcon,
    this.label, {
    this.iconBuilder,
  });

  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// Draws the icon instead of [icon]/[activeIcon], for a tab whose mark is
  /// not a Material glyph. Gets the pill's foreground and background so it
  /// can match either state.
  final Widget Function(bool selected, Color fg, Color bg)? iconBuilder;
}

/// The app's bottom navigation: a frosted bar floating just above the bottom
/// edge, with every destination named.
///
/// It floats, and it is glass, because the list runs underneath it — the shell
/// extends its body behind the bar — so the page does not stop at a hard line
/// above the tabs. Screens under it keep their last row reachable by padding
/// their scroll views with `MediaQuery.paddingOf(context).bottom`, which the
/// shell sets to this bar's height.
///
/// It was once a floating pill where **only the selected tab showed its
/// label**, because five Hebrew labels beside their icons do not fit a narrow
/// phone. Labels stacked under icons at 10.5px fit a 320px screen, so every
/// destination still says what it is.
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

  /// Gap between the bar and the screen's sides and bottom edge.
  static const inset = AppSpace.sm + 2;

  static const radius = 24.0;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        inset,
        0,
        inset,
        // On a phone with a gesture bar the bar sits above it rather than
        // adding the inset on top of it.
        safeBottom > inset ? safeBottom : inset,
      ),
      child: Glass(
        borderRadius: BorderRadius.circular(radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
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
    // On a see-through bar only full-strength ink holds 4.5:1 whatever
    // scrolls beneath, so every label is `textPrimary`. The selected tab is
    // told apart by a filled green pill with a white icon, and by weight —
    // two cues, neither of them colour alone.
    final fg = context.colors.textPrimary;
    final iconFg = selected ? context.colors.onBrand : fg;
    final pill = context.colors.tealFill;

    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppNavBar.radius - 6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.xs + 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The selected tab's icon sits in a soft green pill: on glass,
              // colour and weight alone read weaker than on a flat surface.
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color:
                      selected
                          ? pill
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child:
                    tab.iconBuilder?.call(
                      selected,
                      iconFg,
                      selected ? pill : context.colors.surface,
                    ) ??
                    Icon(
                      selected ? tab.activeIcon : tab.icon,
                      size: 22,
                      color: iconFg,
                    ),
              ),
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
