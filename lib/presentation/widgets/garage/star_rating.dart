import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';

/// Five stars, read-only.
///
/// **Drawn as icons, never as the character ★.** Heebo and Poppins are the
/// only fonts this app ships — Google Fonts was removed for a licence reason —
/// and neither carries U+2605. Flutter's web engine answers a missing glyph by
/// downloading a Noto fallback from Google at runtime, which is exactly the
/// request the bundled fonts exist to prevent. `note_bank_test` fails the build
/// if a star character reappears in `lib`.
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.rating,
    this.size = 15,
  });

  /// 0..5. Halves are rounded to the nearest whole star: a half-lit star reads
  /// as a precision this number does not have.
  final double rating;

  final double size;

  @override
  Widget build(BuildContext context) {
    final lit = rating.round().clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= lit ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: i <= lit
                ? context.colors.warnText
                : context.colors.textSubtle,
          ),
      ],
    );
  }
}

/// Five stars the reader taps to choose one.
class StarPicker extends StatelessWidget {
  const StarPicker({
    super.key,
    required this.rating,
    required this.onChanged,
    this.size = 40,
  });

  /// 0 means nothing chosen yet, which is not a valid review.
  final int rating;
  final ValueChanged<int> onChanged;
  final double size;

  static const _labels = [
    'גרוע',
    'לא טוב',
    'סביר',
    'טוב',
    'מצוין',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                onPressed: () => onChanged(i),
                // Named for screen readers: five identical "star" buttons in a
                // row are unusable without it.
                tooltip: '$i מתוך 5 — ${_labels[i - 1]}',
                icon: Icon(
                  i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: size,
                  color: i <= rating
                      ? context.colors.warnText
                      : context.colors.textSubtle,
                ),
              ),
          ],
        ),
        SizedBox(
          height: 20,
          child: Text(
            rating == 0 ? 'בחרו דירוג' : _labels[rating - 1],
            style: context.text.caption,
          ),
        ),
      ],
    );
  }
}
