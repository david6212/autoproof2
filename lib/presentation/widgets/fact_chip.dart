import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import '../../data/models/car_model.dart';

/// One hard fact, in a bordered pill.
///
/// Replaces the run-on meta line (`92,000 ק"מ · יד 2 · תל אביב · 2019`), where
/// four unrelated facts shared one sentence and the eye had to parse the dots
/// to separate them. Each fact now has its own edge.
class FactChip extends StatelessWidget {
  const FactChip(this.label, {super.key, this.tone});

  final String label;

  /// Optional tint. Null is the neutral pill; pass a colour pair for a fact
  /// that carries meaning of its own.
  final (Color bg, Color fg)? tone;

  /// Vertical padding, exported so [CarCard.heightFor] can budget for a chip
  /// row without guessing at it.
  static const vPad = 4.0;

  /// A chip's height at the ambient text scale: one `micro` line plus its
  /// padding and border.
  static double heightFor(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'X',
        style: DefaultTextStyle.of(context).style.merge(_style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return painter.height + vPad * 2 + 2;
  }

  static const _style = TextStyle(fontSize: 11.5);

  @override
  Widget build(BuildContext context) {
    final bg = tone?.$1;
    final fg = tone?.$2 ?? context.colors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: vPad),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: bg ?? context.colors.cardBorder),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _style.copyWith(color: fg, fontWeight: FontWeight.w500),
      ),
    );
  }
}

final _num = NumberFormat('#,###', 'en');

/// The facts a listing can put on chips, in reading order, skipping whatever
/// it does not know.
///
/// Ownership is worded `בעלות פרטית`, not `בעלים פרטי` — the latter is the
/// SELLER-type badge's label, and the two are different claims. The badge says
/// who is selling; this says how the vehicle is registered. A car registered to
/// a leasing company can be sold by its private driver, and using one phrase
/// for both would flatten exactly the distinction the app exists to show.
List<String> carFacts(CarModel car) {
  final facts = <String>['${_num.format(car.km)} ק"מ'];

  final seats = car.spec?.seats;
  if (seats != null) facts.add('$seats מושבים');

  if (car.spec != null) {
    facts.add(car.spec!.automatic ? 'אוטומטי' : 'ידני');
  }

  final ownership = car.ownership.trim();
  if (ownership.isNotEmpty) {
    facts.add(car.isPrivateOwnership ? 'בעלות פרטית' : ownership);
  }

  return facts;
}

/// A section heading with an optional action at the far end —
/// `רכבים מומלצים … הצג הכל`.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = EdgeInsets.zero,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppText.title)),
          // Without an action the label is a fact about the section (a result
          // count), not a control — so it must not look tappable.
          if (actionLabel != null && onAction == null)
            Text(actionLabel!, style: context.text.caption),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: context.colors.tealText2,
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
                minimumSize: const Size(48, 36),
                textStyle: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
