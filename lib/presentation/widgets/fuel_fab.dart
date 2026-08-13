import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';

/// The shortcut to the fuel-station map, floating on every tab.
///
/// It used to be a row in the profile menu, which meant nobody found it — a
/// map of what is near you right now is not something you go looking for in
/// settings. It sits above the nav bar rather than inside it because the five
/// tabs are places you *are*, and this is an errand you *do*.
class FuelFab extends StatelessWidget {
  const FuelFab({super.key});

  /// Routes that already own their bottom corner. `/discover` is the swipe
  /// deck, whose skip/save buttons sit exactly here — a floating button on top
  /// of them would be both ugly and easy to hit by accident.
  static const _hiddenOn = {'/discover'};

  static bool visibleAt(String location) =>
      !_hiddenOn.any(location.startsWith);

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'fuel-fab',
      onPressed: () => context.push('/fuel'),
      backgroundColor: context.colors.tealFill,
      foregroundColor: context.colors.onBrand,
      tooltip: 'תחנות דלק',
      child: const Icon(Icons.local_gas_station, size: 22),
    );
  }
}
