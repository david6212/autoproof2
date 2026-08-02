import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Widths at which the layout stops being a phone-shaped column.
class AppBreakpoint {
  AppBreakpoint._();

  /// Past this the window is wider than the app has any use for, so the app
  /// is centred instead of stretched. 900 is deliberate: wide enough for two
  /// car cards side by side, narrow enough that a line of Hebrew body text
  /// stays readable — a 1900px paragraph is unreadable no matter how modern
  /// the monitor.
  static const appMaxWidth = 900.0;

  /// Past this the car list becomes a grid rather than one card per row.
  static const carGrid = 620.0;

  /// Past this a screen has room for side-by-side content.
  static const wide = 720.0;
}

/// Centres the whole app once the window is wider than [AppBreakpoint
/// .appMaxWidth], with a plain backdrop either side.
///
/// Installed once in `MaterialApp.builder`, so it covers all 23 screens plus
/// every dialog and bottom sheet — those render through the same Navigator.
///
/// Below the breakpoint this is a pass-through: a phone gets exactly the tree
/// it got before, so no mobile layout can regress.
class ResponsiveFrame extends StatelessWidget {
  const ResponsiveFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= AppBreakpoint.appMaxWidth) return child;

        // A Row (not Center) so the app column inherits the full window
        // height — a Center would leave its child's height unconstrained.
        return ColoredBox(
          color: AppColors.pageBackdrop,
          child: Row(
            children: [
              const Expanded(child: SizedBox.expand()),
              _Edge(),
              SizedBox(width: AppBreakpoint.appMaxWidth, child: child),
              _Edge(),
              const Expanded(child: SizedBox.expand()),
            ],
          ),
        );
      },
    );
  }
}

/// Hairline separating the app column from the backdrop.
class _Edge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 1,
      child: ColoredBox(color: AppColors.cardBorder),
    );
  }
}
