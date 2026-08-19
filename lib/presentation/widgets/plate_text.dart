import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/plate_formatter.dart';

/// A plate on screen. Starred out, and the only place in the app that decides
/// otherwise.
///
/// The rule is one line — never print the digits — but it was being applied
/// per screen, which is why it kept being missed: two screens had grown their
/// own `_plateDisplay` helper, and the two disagreed about how a seven-digit
/// plate is even grouped. One widget means the rule cannot be forgotten by the
/// next screen that shows a car.
///
/// [revealable] belongs to exactly one situation: the owner looking at their
/// own vehicle. They need the number — to hand it to an insurer, to start a
/// transfer — and hiding it from them with no way back would be the app
/// keeping a secret from the person it belongs to. Everyone else gets stars,
/// with no control that could turn them off.
class PlateText extends StatefulWidget {
  const PlateText(
    this.plate, {
    super.key,
    this.revealable = false,
    this.style,
  });

  final String plate;

  /// Whether a tap can show the digits. Only true for the owner.
  final bool revealable;

  final TextStyle? style;

  @override
  State<PlateText> createState() => _PlateTextState();
}

class _PlateTextState extends State<PlateText> {
  /// Never persisted, and never lifted into a provider: a revealed plate goes
  /// back to stars the moment the screen does. "Show my plate" is not a
  /// setting somebody should be able to leave on by accident.
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.plate.trim().isEmpty) return const SizedBox.shrink();

    final style = widget.style ?? context.text.caption;
    final text = _revealed
        ? PlateFormatter.withDashes(widget.plate)
        : PlateFormatter.masked(widget.plate);

    if (!widget.revealable) {
      return Text(text, style: style, textDirection: TextDirection.ltr);
    }

    return Semantics(
      button: true,
      label: _revealed ? 'הסתרת מספר הרישוי' : 'הצגת מספר הרישוי',
      child: InkWell(
        onTap: () => setState(() => _revealed = !_revealed),
        child: Padding(
          // A 44-high strip, so the tap target is reachable without aiming at
          // eight characters of caption type.
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, style: style, textDirection: TextDirection.ltr),
              const SizedBox(width: 6),
              Icon(
                _revealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 16,
                color: context.colors.textSubtle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
