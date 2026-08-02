import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';

/// Bottom TabBar shell for seller screens: בית | המודעה | פרסום | צ'אטים | פרופיל
class SellerShell extends StatelessWidget {
  const SellerShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    _Tab('/seller', Icons.home_outlined, Icons.home, 'בית'),
    _Tab('/seller/listing', Icons.directions_car_outlined,
        Icons.directions_car, 'המודעה'),
    _Tab('/seller/create', Icons.add_circle_outline, Icons.add_circle,
        'פרסום'),
    _Tab('/chats', Icons.chat_bubble_outline, Icons.chat_bubble, 'צ\'אטים'),
    _Tab('/profile', Icons.person_outline, Icons.person, 'פרופיל'),
  ];

  int _indexFor(String location) {
    // Match longest path first so /seller/listing wins over /seller.
    var best = 0;
    var bestLen = -1;
    for (var i = 0; i < _tabs.length; i++) {
      final p = _tabs[i].path;
      if (location.startsWith(p) && p.length > bestLen) {
        best = i;
        bestLen = p.length;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final current = _indexFor(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: current,
        indicatorColor: context.colors.tealLight,
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.activeIcon, color: context.colors.teal),
              label: t.label,
            ),
        ],
      ),
    );
  }
}

class _Tab {
  const _Tab(this.path, this.icon, this.activeIcon, this.label);
  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}
