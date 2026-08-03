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
      bottomNavigationBar: AppNavBar(
        tabs: _tabs,
        currentIndex: current,
        onSelected: (i) => context.go(_tabs[i].path),
      ),
    );
  }
}
