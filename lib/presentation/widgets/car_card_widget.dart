import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_palette.dart';
import '../../data/models/car_model.dart';
import '../../core/theme/app_text.dart';
import 'app_card.dart';
import 'responsive_frame.dart';
import 'seller_type_badge.dart';
import 'heart_check_icon.dart';

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
  });

  final CarModel car;
  final VoidCallback onTap;
  final bool saved;
  final VoidCallback? onToggleSave;

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

    final text = line(AppText.title) +
        2 + // gap under the title
        line(AppText.h3) + // the price
        4 + // gap above the subtitle
        line(_subtitleStyle);
    // 24 = the 12px padding above and below the text block.
    // 2  = AppCard's 1px border, top and bottom. (This is what the original
    //      formula's unexplained trailing "+ 2" was paying for.)
    return photoHeight + 24 + text + 2;
  }

  /// Shared so [heightFor] measures the very style the card renders.
  static const _subtitleStyle = TextStyle(fontSize: 13);

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _photo(context),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    car.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.title,
                  ),
                  const SizedBox(height: 2),
                  // The price is the number people scan a list for, so it gets
                  // its own line and a step more size than the title.
                  Text(
                    '₪${_priceFmt.format(car.price)}',
                    style: AppText.h3.copyWith(color: context.colors.teal),
                  ),
                  const SizedBox(height: 4),
                  // One line, always. [heightFor] budgets for exactly one, so
                  // a wrap here would overflow the grid cell — and this line
                  // wraps easily at a large text scale or on a narrow phone.
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

  String _subtitle() {
    final km = _priceFmt.format(car.km);
    return '$km ק"מ · יד ${car.hand} · ${car.area} · ${car.year}';
  }

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
        // The badge sits at the foot of the photo and the save button at its
        // head, so the two never compete for the same corner and the top of
        // the image — usually the car itself — stays clear.
        Positioned(
            bottom: 10,
            right: 10,
            child: SellerTypeBadge(type: car.sellerType)),
        if (onToggleSave != null)
          Positioned(
            top: 6,
            left: 6,
            child: Material(
              color: context.colors.surface,
              shape: const CircleBorder(),
              child: IconButton(
                iconSize: 20,
                icon: HeartCheckIcon(
                  size: 20,
                  filled: saved,
                  color:
                      saved ? context.colors.teal : context.colors.textMuted,
                  checkColor: context.colors.surface,
                ),
                onPressed: onToggleSave,
              ),
            ),
          ),
        if (car.reviewCount > 0)
          Positioned(
            bottom: 8,
            left: 8,
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
