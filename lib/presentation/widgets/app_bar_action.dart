import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// A text action in the [AppBar], with the one colour that works there.
///
/// A plain `TextButton` in an app bar is very nearly invisible in this app, and
/// nothing about the code looks wrong. `AppBarTheme.foregroundColor` sets the
/// title and the icon theme, but a button brings its own `ButtonStyle`, whose
/// Material default foreground is `colorScheme.primary` — the brand green. The
/// app bar's background is `tealFill`, the same green 6% darker, so the label
/// lands at about **1.2:1** on it. It renders, it is tappable, and it cannot
/// be read.
///
/// Fixing it in `textButtonTheme` would be worse: the same override would put
/// white ink on every dialog and page-level text button, which sit on white.
/// The colour is a property of *where the button is*, so it lives here.
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
    // 6.47:1 the other way round is what makes `tealFill` the fill token in
    // the first place — white is the ink it was chosen to carry.
    final style = TextButton.styleFrom(
      foregroundColor: context.colors.onBrand,
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
