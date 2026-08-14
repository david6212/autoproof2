import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
// `intl` exports its own TextDirection, which shadows Flutter's and turns any
// use of the real one into a confusing "getter 'ltr' isn't defined". Only
// NumberFormat is wanted here.
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../data/models/car_model.dart';
import '../../core/theme/app_text.dart';
import 'app_card.dart';
import 'fact_chip.dart';
import 'responsive_frame.dart';
import 'seller_type_badge.dart';
import 'saved_check_icon.dart';

/// Lays out car cards: one per row on a phone, a grid once the viewport is
/// wide enough for two. Home and Saved share it so the breakpoint and the
/// spacing are decided in one place.
class CarListView extends StatelessWidget {
  const CarListView({
    super.key,
    required this.cars,
    required this.cardBuilder,
    this.header,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 16),
  });

  final List<CarModel> cars;

  /// Builds the card for one listing. The caller owns save/tap behaviour;
  /// this widget owns only where the card sits.
  final Widget Function(CarModel car) cardBuilder;

  /// Optional line above the cards, e.g. a result count.
  final Widget? header;

  final EdgeInsets padding;

  static const _spacing = 14.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isGrid = constraints.maxWidth > AppBreakpoint.carGrid;
        return CustomScrollView(
          slivers: [
            if (header != null)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                    padding.left, padding.top, padding.right, 10),
                sliver: SliverToBoxAdapter(child: header),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                padding.left,
                header == null ? padding.top : 0,
                padding.right,
                padding.bottom,
              ),
              sliver: isGrid ? _grid(context) : _column(),
            ),
          ],
        );
      },
    );
  }

  Widget _column() {
    return SliverList.separated(
      itemCount: cars.length,
      separatorBuilder: (_, __) => const SizedBox(height: _spacing),
      itemBuilder: (context, i) => cardBuilder(cars[i]),
    );
  }

  Widget _grid(BuildContext context) {
    return SliverGrid.builder(
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 460,
        crossAxisSpacing: _spacing,
        mainAxisSpacing: _spacing,
        // A car card's height is fixed by its parts, so the cell can be sized
        // exactly rather than guessed at with an aspect ratio.
        mainAxisExtent: CarCard.heightFor(context),
      ),
      itemCount: cars.length,
      itemBuilder: (context, i) => cardBuilder(cars[i]),
    );
  }
}

/// A single car listing card used on Home and Saved screens.
class CarCard extends StatelessWidget {
  const CarCard({
    super.key,
    required this.car,
    required this.onTap,
    this.saved = false,
    this.onToggleSave,
    this.selected,
  });

  final CarModel car;
  final VoidCallback onTap;
  final bool saved;
  final VoidCallback? onToggleSave;

  /// Non-null puts the card in selection mode (comparison picking): the save
  /// button gives way to a tick circle and the border marks the choice. The
  /// card only DISPLAYS the state — what a tap does stays with [onTap], so the
  /// screen owning the selection owns the behaviour.
  final bool? selected;

  /// Height of the photo strip. [CarListView] needs it to size a grid cell.
  static const photoHeight = 170.0;

  /// The card's total height. The grid on a wide window has to size a cell
  /// before the card exists, so this has to be right — an under-estimate
  /// overflows and Flutter paints the yellow-and-black stripes.
  ///
  /// The three text lines are **measured**, not approximated. The previous
  /// version multiplied hand-tuned pixel guesses (20, 17…) by the text scale,
  /// which silently assumed a font. A guess tuned against one font overflows
  /// under another, and that failure only appears on a real device — which is
  /// exactly where nobody is looking.
  static double heightFor(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final base = DefaultTextStyle.of(context).style;

    double line(TextStyle style) {
      final painter = TextPainter(
        // Any single glyph: only the line's height is wanted, not its width.
        text: TextSpan(text: 'X', style: base.merge(style)),
        // Not a literal: `intl` also exports a `TextDirection`, and the
        // ambient one is the right answer anyway.
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      return painter.height;
    }

    // Title and price share one row, so the row costs one line, not two.
    final text = line(AppText.title) +
        AppSpace.sm + // gap under the title row
        FactChip.heightFor(context) +
        AppSpace.sm + // gap under the chip row
        line(_subtitleStyle);
    // 24 = the 12px padding above and below the text block.
    // 2  = AppCard's 1px border, top and bottom. (This is what the original
    //      formula's unexplained trailing "+ 2" was paying for.)
    return photoHeight + 24 + text + 2;
  }

  /// Shared so [heightFor] measures the very style the card renders.
  ///
  /// 11.5 is the scale's `micro` step. The footer line is the least important
  /// thing on the card — readable when looked at, not competing when not.
  static const _subtitleStyle = TextStyle(fontSize: 11.5);

  static final _priceFmt = NumberFormat('#,###', 'en');

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      // No margin: spacing between cards belongs to [CarListView], which is
      // the only thing that knows whether they are in a column or a grid.
      child: AppCard(
        padding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        borderColor: selected == true ? context.colors.teal : null,
        borderWidth: selected == true ? 2 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _photo(context),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and price on one row. The title takes the slack and
                  // ellipsises; the price is laid out at its natural width and
                  // can never be squeezed by a long model name.
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${car.title} ${car.year}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.title,
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      // Pinned LTR: "₪132,000" is a neutral symbol followed by
                      // digits, and in an RTL paragraph bidi is free to resolve
                      // that either way. Pinning it means the shekel sign
                      // cannot wander to the other end of the number.
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          '₪${_priceFmt.format(car.price)}',
                          style: AppText.title,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.sm),
                  // One chip row, always exactly one line — [heightFor] budgets
                  // for one, so a wrap would overflow a grid cell. Each chip is
                  // Flexible, so a narrow card shrinks them instead.
                  Row(
                    children: [
                      for (final fact in carFacts(car)) ...[
                        Flexible(child: FactChip(fact)),
                        const SizedBox(width: AppSpace.xs + 2),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpace.sm),
                  // `textMuted`, not `textSubtle`: subtle measures 4.23:1 on
                  // white, below the 4.5 floor for text this size.
                  // `palette_test` pins subtle at only 3.0 precisely because it
                  // is for incidental print.
                  Text(
                    _subtitle(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _subtitleStyle.copyWith(
                        color: context.colors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// What the chips do not already say: where the car is and how many owners
  /// it has had. Km and year moved up into the chips and the title.
  String _subtitle() => '${car.area} · יד ${car.hand}';

  Widget _photo(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: photoHeight,
          width: double.infinity,
          child: car.coverPhoto == null
              ? Container(
                  color: context.colors.tealLight,
                  child: Icon(Icons.directions_car,
                      size: 56, color: context.colors.teal),
                )
              : CachedNetworkImage(
                  imageUrl: car.coverPhoto!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: context.colors.tealLight,
                    child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: context.colors.tealLight,
                    child: Icon(Icons.directions_car,
                        size: 56, color: context.colors.teal),
                  ),
                ),
        ),
        // Badge at the foot, save button at the head, both on the leading
        // edge — the two never share a corner, and the middle of the photo
        // (which is the car) stays clear.
        PositionedDirectional(
          bottom: 10,
          start: 10,
          child: SellerTypeBadge(type: car.sellerType),
        ),
        // Says where the listing's facts came from, on the listing itself
        // rather than only on the car page. Every listing is built from a
        // plate lookup, so this is true of all of them.
        PositionedDirectional(
          top: 10,
          end: 10,
          child: FactChip(
            'נתונים רשמיים',
            tone: (context.colors.surface, context.colors.tealText),
          ),
        ),
        if (selected != null)
          PositionedDirectional(
            top: 10,
            start: 10,
            // Not a button: in selection mode the whole card is the target,
            // and a second tappable circle inside it would give the same tap
            // two meanings.
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected!
                    ? context.colors.tealFill
                    : Colors.black.withValues(alpha: 0.40),
                shape: BoxShape.circle,
                border: Border.all(color: context.colors.onBrand, width: 1.5),
              ),
              child: selected!
                  ? Icon(Icons.check,
                      size: 22, color: context.colors.onBrand)
                  : null,
            ),
          )
        else if (onToggleSave != null)
          PositionedDirectional(
            top: 10,
            start: 10,
            // The circle carries the state, the check never changes colour.
            // Unsaved it is a dark scrim — the button sits on a photograph,
            // and a white disc is invisible on a photo of a white car. Saved,
            // it fills with the brand green. White reads on both (5.07:1 on
            // the fill), so the tick stays legible either way and the only
            // thing that moves is the disc behind it.
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: saved
                    ? context.colors.tealFill
                    : Colors.black.withValues(alpha: 0.40),
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  tooltip: saved ? 'הסר מהשמורים' : 'שמור',
                  icon: SavedCheckIcon(
                    size: 20,
                    filled: saved,
                    color: context.colors.onBrand,
                  ),
                  onPressed: onToggleSave,
                ),
              ),
            ),
          ),
        if (car.reviewCount > 0)
          PositionedDirectional(
            bottom: 8,
            end: 8,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: context.colors.tealDark.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, size: 13, color: context.colors.starColor),
                  const SizedBox(width: 4),
                  Text(
                    '${car.reviewCount} חוות דעת',
                    style: TextStyle(
                        color: context.colors.onBrand, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
