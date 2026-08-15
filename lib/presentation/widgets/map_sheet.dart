import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// The draggable panel over a map, shared by the two screens built on one:
/// fuel stations and inspection centres.
///
/// Both used to be map OR list behind a toggle, which made you choose between
/// seeing where things are and reading what they are. Then both became a fixed
/// split — map on top, list below — which showed you both but decided the
/// proportion for you. Now the map fills the screen and this slides over it,
/// so the proportion is the user's.
///
/// The stops live here rather than on either screen: two screens that
/// disagreed about how far a sheet opens would read as two products.

/// Pulled right down. Still shows the handle and the first row, so there is
/// always something to grab to bring it back.
const kSheetMin = 0.22;

/// Where it opens. Above half, because the map orients you but the list is
/// what you act on.
const kSheetInitial = 0.62;

/// Pulled right up — deliberately short of the full screen. Some map has to
/// stay visible, or the screen quietly becomes a list and the user has lost
/// the thing they opened a map for.
const kSheetMax = 0.92;

/// The stops a drag snaps to, so a sheet lands somewhere deliberate rather
/// than wherever a finger stopped.
const kSheetStops = [kSheetMin, kSheetInitial, kSheetMax];

/// The panel itself: a rounded, shadowed surface with a grab handle.
class MapSheet extends StatelessWidget {
  const MapSheet({super.key, required this.child});

  final Widget child;

  static const radius = 22.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(radius),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [const _Grabber(), Expanded(child: child)],
      ),
    );
  }
}

/// The bar that says "this panel moves".
class _Grabber extends StatelessWidget {
  const _Grabber();

  /// Height of the whole grab area, not just the visible bar — the bar itself
  /// is 4px, which is nothing to aim at.
  static const height = 22.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Container(
          width: 42,
          height: 4,
          decoration: BoxDecoration(
            color: context.colors.cardBorder,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
