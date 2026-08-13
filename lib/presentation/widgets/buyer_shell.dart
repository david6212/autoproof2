import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_nav_bar.dart';
import 'saved_check_icon.dart';

/// Bottom TabBar shell for buyer screens: בית | שמורים | דלק | צ'אטים | פרופיל
///
/// The third slot used to be the swipe deck ("גילוי"). It showed the same cars
/// the home list already showed, through the same filter, so it was a second
/// route to the same place rather than a second thing to do. The fuel map
/// takes the slot: it is somewhere a driver actually goes.
class BuyerShell extends StatelessWidget {
  const BuyerShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    NavTab('/home', Icons.home_outlined, Icons.home, 'בית'),
    NavTab('/saved', Icons.check_rounded, Icons.check_rounded, 'שמורים',
        iconBuilder: savedTabIcon),
    // Both states use the FILLED glyph, unlike the other tabs. The outlined
    // variant is a separate codepoint used nowhere else, and `flutter build`
    // shrinks the icon font to only the glyphs in use — so a browser holding a
    // font from a build without it renders an invisible tab. The filled glyph
    // ships with the fuel feature anyway (the map pin and the seller shell's
    // shortcut both use it), so leaning on it removes the whole failure mode.
    NavTab('/fuel', Icons.local_gas_station, Icons.local_gas_station, 'דלק'),
    NavTab('/chats', Icons.chat_bubble_outline, Icons.chat_bubble, 'צ\'אטים'),
    NavTab('/profile', Icons.person_outline, Icons.person, 'פרופיל'),
  ];

  /// The destinations, for tests — a tab pointing at a route that no longer
  /// exists is a runtime blank page, not a compile error.
  static List<String> get tabPaths => [for (final t in _tabs) t.path];

  /// The destinations themselves, so a test can render the real bar.
  static List<NavTab> get tabs => _tabs;

  int _indexFor(String location) {
    final i = _tabs.indexWhere((t) => location.startsWith(t.path));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final current = _indexFor(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: AppNavBar(
        tabs: _tabs,
        currentIndex: current,
        onSelected: (i) => context.go(_tabs[i].path),
      ),
    );
  }
}
