import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_nav_bar.dart';

/// Bottom TabBar shell for seller screens: בית | המודעה | פרסום | צ'אטים | פרופיל
class SellerShell extends StatelessWidget {
  const SellerShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    NavTab('/seller', Icons.home_outlined, Icons.home, 'בית'),
    NavTab('/seller/listing', Icons.directions_car_outlined,
        Icons.directions_car, 'המודעה'),
    NavTab('/seller/create', Icons.add_circle_outline, Icons.add_circle,
        'פרסום'),
    NavTab('/chats', Icons.chat_bubble_outline, Icons.chat_bubble, 'צ\'אטים'),
    NavTab('/profile', Icons.person_outline, Icons.person, 'פרופיל'),
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
      // No floating shortcut here. A fuel-station button hovering over
      // "פרסם את הרכב שלך" answers a question nobody is asking mid-sale, and a
      // floating button is the loudest thing on a screen — it should be the
      // one action that screen is for. Fuel keeps its tab on the buyer side,
      // one tap away.
      bottomNavigationBar: AppNavBar(
        tabs: _tabs,
        currentIndex: current,
        onSelected: (i) => context.go(_tabs[i].path),
      ),
    );
  }
}
