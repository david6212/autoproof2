import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';

/// One specification, as a bordered tile: an icon, what the field is, and what
/// this car's value for it is.
///
/// Replaces a wash of brand green filled with rounded pills. The pills put the
/// value on screen but never named the field — "בנזין" and "כסף מטלי" sat side
/// by side with nothing saying which was fuel and which was colour. A tile
/// carries its own label, so a spec can be read without already knowing the
/// order.
class SpecTile extends StatelessWidget {
  const SpecTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;

  /// The field — `סוג מנוע`.
  final String label;

  /// This car's value — `בנזין 1998 סמ"ק`.
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.colors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The icon sits at the far end, away from the text, so the two
          // columns of tiles read as two columns of words rather than a grid
          // of icons.
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Icon(icon, size: 17, color: context.colors.teal),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodySm.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpace.xxs),
          Text(value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.caption),
        ],
      ),
    );
  }
}

/// Lays [tiles] out two to a row, stretched to equal height.
///
/// A `GridView` would need a fixed aspect ratio, and these tiles are sized by
/// their text — which changes with the text scale and with how long a value is.
class SpecTileGrid extends StatelessWidget {
  const SpecTileGrid({super.key, required this.tiles});

  final List<SpecTile> tiles;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      final pair = tiles.skip(i).take(2).toList();
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: pair.first),
            const SizedBox(width: AppSpace.md),
            // An odd count leaves the last row half empty rather than letting
            // one tile stretch to the full width and look like a heading.
            Expanded(
              child: pair.length > 1 ? pair[1] : const SizedBox.shrink(),
            ),
          ],
        ),
      ));
      if (i + 2 < tiles.length) {
        rows.add(const SizedBox(height: AppSpace.md));
      }
    }
    return Column(children: rows);
  }
}

/// How a record reads on its own: nothing to say, reassuring, or a warning.
enum RecordTone { neutral, good, bad }

/// One official record, as a row: a status icon in a tinted disc, the field and
/// its value, and a chevron when there is somewhere to go.
class RecordRow extends StatelessWidget {
  const RecordRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.tone = RecordTone.neutral,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final RecordTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      RecordTone.good => (context.colors.tealLight, context.colors.tealText),
      RecordTone.bad => (context.colors.errorBg, context.colors.errorRed),
      RecordTone.neutral => (
          context.colors.background,
          context.colors.textMuted,
        ),
    };

    final row = Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.colors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppText.bodySm.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpace.xxs),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.caption),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: fg),
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpace.xs),
            Icon(Icons.chevron_left,
                size: 20, color: context.colors.textSubtle),
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: row,
    );
  }
}
