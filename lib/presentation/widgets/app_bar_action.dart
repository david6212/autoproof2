import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// A text action in the [AppBar], with the one colour that works there.
///
/// A plain `TextButton` in an app bar takes its own `ButtonStyle` default —
/// `colorScheme.primary`, the brand green — and `AppBarTheme.foregroundColor`
/// does not reach it. On the old green bar that landed at about **1.2:1**:
/// rendered, tappable, unreadable. The bar is now the page colour, which makes
/// it survivable rather than fixed — the same default measures **3.77:1** on
/// it, still under the 4.5 floor for a label.
///
/// So this uses `tealText2`, the token for green ink on a light surface:
/// **6.42:1** light, **8.99:1** dark. It reads as the brand without being the
/// identity green, which is reserved for the mark.
///
/// Fixing it in `textButtonTheme` would still be wrong — that override would
/// reach every dialog and page-level text button too, and what ink a button
/// needs is a property of *where it sits*.
class AppBarAction extends StatelessWidget {
  const AppBarAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: context.colors.tealText2,
      minimumSize: const Size(48, 48),
    );

    if (icon == null) {
      return TextButton(style: style, onPressed: onPressed, child: Text(label));
    }
    return TextButton.icon(
      style: style,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
