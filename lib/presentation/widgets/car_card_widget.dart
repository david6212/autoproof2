import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/car_model.dart';
import '../../core/theme/app_text.dart';
import 'app_card.dart';
import 'responsive_frame.dart';
import 'seller_type_badge.dart';

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

  /// The card's total height: the photo, plus padding and two single lines of
  /// text that grow with the user's text-size setting.
  static double heightFor(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return photoHeight + 24 + (20 + 4 + 17) * scale + 2;
  }

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
            _photo(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          car.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.title,
                        ),
                      ),
                      Text(
                        '₪${_priceFmt.format(car.price)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.teal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _subtitle(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
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

  Widget _photo() {
    return Stack(
      children: [
        SizedBox(
          height: photoHeight,
          width: double.infinity,
          child: car.coverPhoto == null
              ? Container(
                  color: AppColors.tealLight,
                  child: const Icon(Icons.directions_car,
                      size: 56, color: AppColors.teal),
                )
              : CachedNetworkImage(
                  imageUrl: car.coverPhoto!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: AppColors.tealLight,
                    child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.tealLight,
                    child: const Icon(Icons.directions_car,
                        size: 56, color: AppColors.teal),
                  ),
                ),
        ),
        Positioned(top: 10, right: 10, child: SellerTypeBadge(type: car.sellerType)),
        if (onToggleSave != null)
          Positioned(
            top: 6,
            left: 6,
            child: Material(
              color: AppColors.surface,
              shape: const CircleBorder(),
              child: IconButton(
                iconSize: 20,
                icon: Icon(
                  saved ? Icons.favorite : Icons.favorite_border,
                  color: saved ? AppColors.errorRed : AppColors.textMuted,
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
                color: AppColors.tealDark.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 13, color: AppColors.starColor),
                  const SizedBox(width: 4),
                  Text(
                    '${car.reviewCount} חוות דעת',
                    style: const TextStyle(
                        color: AppColors.onBrand, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
