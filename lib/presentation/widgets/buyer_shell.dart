import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';

/// Bottom TabBar shell for buyer screens: בית | שמורים | גילוי | צ'אטים | פרופיל
class BuyerShell extends StatelessWidget {
  const BuyerShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    _Tab('/home', Icons.home_outlined, Icons.home, 'בית'),
    _Tab('/saved', Icons.favorite_border, Icons.favorite, 'שמורים'),
    _Tab('/discover', Icons.explore_outlined, Icons.explore, 'גילוי'),
    _Tab('/chats', Icons.chat_bubble_outline, Icons.chat_bubble, 'צ\'אטים'),
    _Tab('/profile', Icons.person_outline, Icons.person, 'פרופיל'),
  ];

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
