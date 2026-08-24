import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import '../../data/models/car_model.dart';
import '../providers/vehicle_provider.dart';
import 'app_card.dart';
import 'document_list.dart';
import 'service_timeline.dart';

/// The seller's service history and shared documents, on the listing.
///
/// Renders nothing at all when the listing did not come from a passport, which
/// is most of them. That absence is deliberately silent: a card saying "this
/// seller kept no records" would be an accusation, and the seller may have a
/// full paper folder in the glovebox. The badge rewards documentation; it does
/// not punish its absence.
class DocumentedHistoryCard extends ConsumerWidget {
  const DocumentedHistoryCard({super.key, required this.car});

  final CarModel car;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleId = car.vehicleId;
    if (vehicleId == null) return const SizedBox.shrink();

    final servicesAsync = ref.watch(vehicleServicesProvider(vehicleId));
    final services = servicesAsync.valueOrNull ?? const [];
    final documents = ref.watch(sharedDocumentsProvider(vehicleId)).valueOrNull ??
        const [];

    if (services.isEmpty && documents.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('היסטוריית טיפולים', style: AppText.h3),
            ),
            if (car.hasDocumentedHistory)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.sm,
                  vertical: AppSpace.xxs,
                ),
                decoration: BoxDecoration(
                  color: colors.tealLight,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  'תיק מתועד',
                  style: AppText.bodySm.copyWith(
                    color: colors.tealText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          services.length == 1
              ? 'רשומה אחת שתועדה על ידי הבעלים'
              : '${services.length} רשומות שתועדו על ידי הבעלים'
                  '${car.historySpanMonths > 0 ? ' לאורך ${car.historySpanMonths} חודשים' : ''}',
          style: context.text.bodyMuted,
        ),
        const SizedBox(height: AppSpace.md),

        // Read-only: no onCorrect, so no way for a visitor to write into
        // someone else's history.
        ServiceTimeline(records: services),

        if (documents.isNotEmpty) ...[
          const SizedBox(height: AppSpace.lg),
          const Text('מסמכים שהמוכר שיתף', style: AppText.subtitle),
          const SizedBox(height: AppSpace.md),
          DocumentList(
            vehicleId: vehicleId,
            documents: documents,
            readOnly: true,
          ),
          const SizedBox(height: AppSpace.sm),
          AppCard(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Text(
              'המסמכים הועלו על ידי המוכר ולא נבדקו על ידי BonnetCheck.',
              style: context.text.caption,
            ),
          ),
        ],
      ],
    );
  }
}
