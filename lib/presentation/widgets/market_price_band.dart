import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/market_stats.dart';
import '../../data/models/car_model.dart';
import '../providers/cars_provider.dart';
import 'app_card.dart';

/// Where this asking price sits among comparable listings, and how long cars
/// like it have been up.
///
/// **Renders nothing below eight comparable listings**, which today means it
/// renders nothing at all — there are four demo cars. That is not a bug and it
/// is not a placeholder waiting to be filled: it is the rule working. The
/// widget appears by itself once there is enough of a market to describe.
class MarketPriceBand extends ConsumerWidget {
  const MarketPriceBand({super.key, required this.car});

  final CarModel car;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Every active listing, not the filtered view: the market a price is
    // measured against must not shrink because the buyer ticked a filter.
    final all = ref.watch(activeCarsProvider).valueOrNull ?? const <CarModel>[];
    final stats = MarketStats.forCar(car, all);
    if (stats == null) return const SizedBox.shrink();

    final colors = context.colors;
    final money = NumberFormat.decimalPattern('he');
    final standing = stats.standingOf(car.price);
    final days = MarketStats.daysOnMarket(car);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_outlined, size: 20, color: colors.teal),
              const SizedBox(width: AppSpace.sm),
              const Expanded(
                child: Text('המחיר מול השוק', style: AppText.subtitle),
              ),
              Text(standing.label, style: context.text.captionBold),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          _Band(position: stats.positionOf(car.price)),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              Text('${money.format(stats.p25.round())} ₪',
                  style: context.text.caption),
              const Spacer(),
              Text('${money.format(stats.p75.round())} ₪',
                  style: context.text.caption),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            'מבוסס על ${stats.sampleSize} מודעות דומות באפליקציה '
            '(${car.make} ${car.model}, ±${MarketStats.yearWindow} שנים). '
            'זהו טווח מחירי הבקשה, לא הערכת שווי.',
            style: context.text.caption,
          ),
          const Divider(height: AppSpace.xl),
          Row(
            children: [
              Icon(Icons.schedule, size: 18, color: colors.textMuted),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  'בשוק ${days == 0 ? 'מהיום' : '$days ימים'} · '
                  'הממוצע לדגם: ${stats.avgDaysOnMarket.round()} ימים',
                  style: AppText.bodySm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The band, with a marker where this car falls.
class _Band extends StatelessWidget {
  const _Band({required this.position});

  /// 0 at the 25th percentile, 1 at the 75th.
  final double position;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const markerWidth = 3.0;

        return SizedBox(
          height: 22,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: colors.tealLight,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              // Positioned from the start edge so it mirrors correctly in RTL
              // — a marker that reads "cheap" in Hebrew and "dear" in English
              // would be worse than no marker.
              PositionedDirectional(
                start: (position * (width - markerWidth))
                    .clamp(0.0, width - markerWidth),
                top: 0,
                bottom: 0,
                child: Container(
                  width: markerWidth,
                  decoration: BoxDecoration(
                    color: colors.tealText,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
