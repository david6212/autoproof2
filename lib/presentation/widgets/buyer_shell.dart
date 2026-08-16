import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_nav_bar.dart';

/// Bottom TabBar shell for buyer screens: בית | הרכב שלי | דלק | צ'אטים | פרופיל
///
/// The third slot used to be the swipe deck ("גילוי"). It showed the same cars
/// the home list already showed, through the same filter, so it was a second
/// route to the same place rather than a second thing to do. The fuel map
/// takes the slot: it is somewhere a driver actually goes.
///
/// The second slot used to be שמורים, and gave it up to the garage. Five tabs
/// is the ceiling on a phone, and the two are not comparable in what they are
/// for: saved listings matter for the weeks somebody is shopping, the passport
/// matters for the years they own the car. Saved moved into the profile and is
/// still reachable in two taps — it keeps the nav bar and lights up the
/// profile tab, so it reads as living there rather than as a page that lost
/// its home.
class BuyerShell extends StatelessWidget {
  const BuyerShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    NavTab('/home', Icons.home_outlined, Icons.home, 'בית'),
    NavTab('/garage', Icons.directions_car_outlined, Icons.directions_car,
        'הרכב שלי'),
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

  /// Routes that sit inside the shell without owning a tab. They light up the
  /// tab they were opened from, so the bar never claims the user is somewhere
  /// they are not.
  static const _adoptedBy = {'/saved': '/profile'};

  /// Exposed for tests: which tab a location lights up.
  static int indexForLocation(String location) {
    for (final entry in _adoptedBy.entries) {
      if (location.startsWith(entry.key)) {
        return _tabs.indexWhere((t) => t.path == entry.value);
      }
    }
    final i = _tabs.indexWhere((t) => location.startsWith(t.path));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final current = indexForLocation(location);

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
