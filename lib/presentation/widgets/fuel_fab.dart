import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';

/// Floating shortcut to the fuel-station map.
///
/// The buyer side gives fuel its own tab, so this is only used by the seller
/// shell, whose five slots are all spoken for. It briefly had a rule for
/// hiding itself over the swipe deck's buttons; the deck is gone, and so is
/// the rule.
class FuelFab extends StatelessWidget {
  const FuelFab({super.key});

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
