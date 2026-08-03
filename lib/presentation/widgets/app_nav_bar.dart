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

/// The app's bottom navigation: a floating rounded bar, with the selected
/// tab sitting inside a filled pill that carries its label.
///
/// Replaces Material's edge-to-edge `NavigationBar`. Only the selected tab
/// shows its label — five Hebrew labels side by side do not fit a narrow
/// phone, and the pill is what tells you where you are.
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
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: context.colors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < tabs.length; i++)
              Flexible(
                child: _NavItem(
                  tab: tabs[i],
                  selected: i == currentIndex,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
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

  @override
  Widget build(BuildContext context) {
    final fg = selected ? context.colors.onBrand : context.colors.textSubtle;
    final bg = selected ? context.colors.teal : context.colors.surface;

    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            horizontal: selected ? 14 : 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: selected ? bg : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              tab.iconBuilder?.call(selected, fg, bg) ??
                  Icon(selected ? tab.activeIcon : tab.icon,
                      size: 22, color: fg),
              // The label belongs to the pill, so it appears and disappears
              // with it rather than being permanently squeezed in.
              if (selected) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    tab.label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: TextStyle(
                      color: fg,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
