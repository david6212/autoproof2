import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/car_model.dart';
import 'verified_badge_widget.dart';

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

  static final _priceFmt = NumberFormat('#,###', 'en');

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
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
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
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
          height: 170,
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
        const Positioned(top: 10, right: 10, child: VerifiedBadge()),
        if (onToggleSave != null)
          Positioned(
            top: 6,
            left: 6,
            child: Material(
              color: AppColors.white,
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
                        color: AppColors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
