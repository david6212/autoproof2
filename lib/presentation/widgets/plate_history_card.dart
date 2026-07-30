import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../providers/cars_provider.dart';
import '../providers/gov_api_provider.dart';
import 'app_card.dart';

/// Odometer cross-check + cross-listing memory for a plate. Compares the
/// current listing's km against BOTH the official gov odometer (last test) and
/// this plate's past AutoProof listings, flagging a rollback (any earlier
/// reading higher than now). Renders nothing when there's nothing to compare.
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
    final history =
        ref.watch(plateHistoryProvider(plate)).valueOrNull ?? const [];
    final govData = ref.watch(govDataForPlateProvider(plate)).valueOrNull;

    final previous = history.where((s) => s.carId != currentCarId).toList();
    final govKm = (govData?.lastTestKm != null && govData!.lastTestKm! > 0)
        ? govData.lastTestKm!
        : null;

    final govRollback = govKm != null && govKm > currentKm;
    final histRollback = previous.any((s) => s.km > currentKm);

    // Nothing to show if there's neither an official reading nor prior listings.
    if (govKm == null && previous.isEmpty) return const SizedBox.shrink();

    return AppSectionCard(
      icon: Icons.speed,
      title: 'בדיקת קילומטראז\' והיסטוריה',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rollback warning (from official record and/or a past listing).
          if (govRollback || histRollback) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.errorBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 20, color: AppColors.errorRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      govRollback
                          ? 'אזהרת קילומטראז\': המודעה מציגה פחות ק"מ מהמד-אוץ הרשמי בטסט האחרון. ייתכן גילגול.'
                          : 'אזהרת קילומטראז\': במודעה קודמת נרשמו יותר ק"מ מהמודעה הנוכחית. ייתכן גילגול.',
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.errorRed),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Official odometer (from the last annual test).
          if (govKm != null)
            _kmRow(
              icon: Icons.verified_user,
              // Naming the source is a licence obligation, not just nice-to-have.
              label: 'מד-אוץ רשמי · משרד התחבורה (טסט אחרון)',
              km: govKm,
              flagged: govRollback,
              okNote: 'תואם ✓',
            ),

          // Past AutoProof listings.
          if (previous.isNotEmpty) ...[
            if (govKm != null) const SizedBox(height: 6),
            const SizedBox(height: 6),
            Text('מודעות קודמות באפליקציה (${previous.length})',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted)),
            const SizedBox(height: 8),
            for (final s in previous)
              _kmRow(
                icon: Icons.history,
                label: _dateFmt.format(s.createdAt),
                km: s.km,
                flagged: s.km > currentKm,
                trailing: '₪${_fmt.format(s.price)}',
              ),
          ],
        ],
      ),
    );
  }

  Widget _kmRow({
    required IconData icon,
    required String label,
    required int km,
    required bool flagged,
    String? okNote,
    String? trailing,
  }) {
    final kmColor = flagged ? AppColors.errorRed : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: flagged ? AppColors.errorRed : AppColors.teal),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textMuted)),
          ),
          Text('${_fmt.format(km)} ק"מ',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: kmColor)),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            Text(trailing,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textMuted)),
          ] else if (okNote != null && !flagged) ...[
            const SizedBox(width: 8),
            Text(okNote,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.teal)),
          ],
        ],
      ),
    );
  }
}
