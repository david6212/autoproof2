import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/plate_snapshot_model.dart';
import '../providers/cars_provider.dart';

/// Shows this plate's PAST listings on AutoProof (cross-listing memory) and
/// flags an odometer rollback — a previous listing that showed MORE km than
/// the current one. Renders nothing when the car has no prior listings.
class PlateHistoryCard extends ConsumerWidget {
  const PlateHistoryCard({
    super.key,
    required this.plate,
    required this.currentCarId,
    required this.currentKm,
  });

  final String plate;
  final String currentCarId;
  final int currentKm;

  static final _fmt = NumberFormat('#,###', 'en');
  static final _dateFmt = DateFormat('MM/yyyy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(plateHistoryProvider(plate));
    return async.maybeWhen(
      data: (all) {
        final previous =
            all.where((s) => s.carId != currentCarId).toList();
        if (previous.isEmpty) return const SizedBox.shrink();

        // Rollback: an older listing showed more km than the current one.
        final rollback = previous.any((s) => s.km > currentKm);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.history, size: 18, color: AppColors.teal),
                  SizedBox(width: 6),
                  Text('היסטוריית מודעות באפליקציה',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textPrimary)),
                ],
              ),
              const SizedBox(height: 4),
              Text('הרכב פורסם כאן ${previous.length} פעמים בעבר.',
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textMuted)),
              if (rollback) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 20, color: AppColors.errorRed),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'אזהרת קילומטראז\': במודעה קודמת נרשמו יותר ק"מ מהמודעה הנוכחית. ייתכן גילגול מד-אוץ.',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.errorRed),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              for (final s in previous) _row(s),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _row(PlateSnapshot s) {
    final higher = s.km > currentKm;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 7, color: AppColors.textSubtle),
          const SizedBox(width: 8),
          Text(_dateFmt.format(s.createdAt),
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textMuted)),
          const SizedBox(width: 10),
          Text('${_fmt.format(s.km)} ק"מ',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: higher ? AppColors.errorRed : AppColors.textPrimary)),
          const Spacer(),
          Text('₪${_fmt.format(s.price)}',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
