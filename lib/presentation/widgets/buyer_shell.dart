import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_nav_bar.dart';
import 'saved_check_icon.dart';

/// Bottom TabBar shell for buyer screens: בית | שמורים | גילוי | צ'אטים | פרופיל
class BuyerShell extends StatelessWidget {
  const BuyerShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    NavTab('/home', Icons.home_outlined, Icons.home, 'בית'),
    NavTab('/saved', Icons.check_rounded, Icons.check_rounded, 'שמורים',
        iconBuilder: savedTabIcon),
    NavTab('/discover', Icons.explore_outlined, Icons.explore, 'גילוי'),
    NavTab('/chats', Icons.chat_bubble_outline, Icons.chat_bubble, 'צ\'אטים'),
    NavTab('/profile', Icons.person_outline, Icons.person, 'פרופיל'),
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
      bottomNavigationBar: AppNavBar(
        tabs: _tabs,
        currentIndex: current,
        onSelected: (i) => context.go(_tabs[i].path),
      ),
    );
  }
}
