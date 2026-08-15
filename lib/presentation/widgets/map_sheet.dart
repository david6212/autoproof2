import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// The map-above-list layout, shared by the two screens built on a map:
/// fuel stations and inspection centres.
///
/// Both used to be map OR list behind a toggle, which made you choose between
/// seeing where things are and reading what they are. Showing both at once is
/// the whole point, so the split has to be decided in one place — two screens
/// that disagree about how much map to show would read as two products.

/// A map header must stay big enough to place a pin in.
const kMinMapHeight = 180.0;

/// …and small enough that the list is still the page.
const kMaxMapHeight = 300.0;

/// How tall the map header is for a given viewport.
///
/// A third of the screen, clamped. The clamp is what makes it work at both
/// ends: a third of a tall tablet is a wall of map, and a third of a short
/// landscape window is a green stripe with nothing legible in it.
///
/// A plain function rather than a layout widget, so the rule can be TESTED —
/// a tile layer needs the network, and a widget test cannot load a live map.
double mapHeaderHeight(double viewport, {bool expanded = false}) =>
    expanded ? viewport : (viewport * 0.34).clamp(kMinMapHeight, kMaxMapHeight);

/// The panel the list sits in, rising over the foot of the map.
///
/// The overlap is what makes the two read as one screen rather than as a map
/// with a list stuck underneath it: the sheet's rounded top edge cuts across
/// the map, so the map clearly continues behind it.
class MapSheet extends StatelessWidget {
  const MapSheet({super.key, required this.child, this.draggable = false});

  final Widget child;

  /// Shows a grab handle and drops the overlap.
  ///
  /// A fixed sheet sits *under* the map and lifts over its foot, so it needs
  /// the negative offset. A draggable one is positioned by the sheet itself and
  /// must not shift, or every drag would fight a 16px correction — and it needs
  /// a handle, because a panel that moves has to look like it moves.
  final bool draggable;

  static const overlap = 16.0;
  static const radius = 22.0;

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      padding: EdgeInsets.only(bottom: draggable ? 0 : overlap),
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
      child: draggable
          ? Column(children: [const _Grabber(), Expanded(child: child)])
          : child,
    );

    if (draggable) return panel;

    // Gives back the height the overlap took, so the list still reaches the
    // bottom of the screen instead of stopping 16px short.
    return Transform.translate(
      offset: const Offset(0, -overlap),
      child: panel,
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
