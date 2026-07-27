import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../providers/gov_api_provider.dart';

/// At-a-glance summary of the official red flags for a plate (accident /
/// structural change, open recalls, off-road / cancelled), pulled forward from
/// the full history screen so buyers can't miss them. Shows a clean green state
/// when the official record is fine. Renders nothing until gov data loads.
class GovRedFlagsCard extends ConsumerWidget {
  const GovRedFlagsCard({super.key, required this.plate});

  final String plate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gov = ref.watch(govDataForPlateProvider(plate)).valueOrNull;
    if (gov == null) return const SizedBox.shrink();

    final flags = <(_Severity, String)>[
      if (gov.offRoad)
        (_Severity.critical, 'הרכב ירד מהכביש / בוטל סופית ברישום'),
      if (gov.structuralChange)
        (_Severity.high, 'רישום שינוי מבנה — ייתכן תיקון לאחר תאונה'),
      if (gov.recalls.isNotEmpty)
        (_Severity.high, '${gov.recalls.length} קריאות שירות פתוחות (ריקול)'),
    ];

    if (flags.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.tealLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.verified, size: 18, color: AppColors.teal),
            SizedBox(width: 8),
            Expanded(
              child: Text('אין דגלים אדומים רשמיים ברשומות משרד התחבורה',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.tealText)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.report_gmailerrorred, size: 18, color: AppColors.errorRed),
              SizedBox(width: 6),
              Text('דגלים אדומים רשמיים',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.errorRed)),
            ],
          ),
          const SizedBox(height: 10),
          for (final (sev, text) in flags)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    sev == _Severity.critical
                        ? Icons.dangerous
                        : Icons.warning_amber_rounded,
                    size: 17,
                    color: AppColors.errorRed,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(text,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

enum _Severity { critical, high }
