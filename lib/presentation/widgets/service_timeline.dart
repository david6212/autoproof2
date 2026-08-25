import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import '../../data/models/service_record.dart';
import 'app_card.dart';
import 'photo_viewer.dart';

/// A vehicle's service history, newest first.
///
/// **The owner may edit a record. Nobody may delete one**, and that half is
/// still the feature: fixing a wrong figure leaves a history, erasing an
/// inconvenient service does not. If a future change adds a delete action
/// here, the "תיק מתועד" badge stops meaning anything.
///
/// An edited record carries a visible mark and the date it changed. That mark
/// is what an editable history costs, and it is not optional — without it the
/// list would be a log that quietly rewrote itself while still being shown to
/// buyers as evidence.
///
/// [onEdit] is null in the buyer's view — a buyer reads the history, they do
/// not write to it. [onCorrect] predates editing and is kept for the records
/// written while it was the only way to fix one.
class ServiceTimeline extends StatelessWidget {
  const ServiceTimeline({
    super.key,
    required this.records,
    this.onCorrect,
    this.onEdit,
    this.showFooter = true,
  });

  final List<ServiceRecord> records;
  final void Function(ServiceRecord record)? onCorrect;
  final void Function(ServiceRecord record)? onEdit;

  /// The line explaining why nothing here can be edited. Shown to owners and
  /// to buyers alike — for the buyer it is the whole reason to trust the list.
  final bool showFooter;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const SizedBox.shrink();

    // Which records have been corrected, so the original can say so.
    final correctedIds = <String>{
      for (final r in records)
        if (r.correctsServiceId != null) r.correctsServiceId!,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in records)
          _ServiceRow(
            record: r,
            wasCorrected: correctedIds.contains(r.id),
            onCorrect: onCorrect,
            onEdit: onEdit,
          ),
        if (showFooter) ...[
          const SizedBox(height: AppSpace.md),
          Text(
            'רשומה שעודכנה מסומנת ומציינת מתי. מחיקה אינה אפשרית. '
            'הרשומות הוזנו על ידי בעל הרכב ולא אומתו על ידי BonnetCheck.',
            style: context.text.caption,
          ),
        ],
      ],
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.record,
    required this.wasCorrected,
    this.onCorrect,
    this.onEdit,
  });

  final ServiceRecord record;
  final bool wasCorrected;
  final void Function(ServiceRecord record)? onCorrect;
  final void Function(ServiceRecord record)? onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: AppCard(
        borderColor: record.isCorrection ? colors.warnText : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconFor(record.type), size: 20, color: colors.teal),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    record.title.isEmpty ? record.type.label : record.title,
                    style: AppText.subtitle,
                  ),
                ),
                if (record.cost > 0)
                  Text('${_thousands(record.cost)} ₪',
                      style: AppText.bodySm),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            // The garage's name is a link when the owner picked it from the
            // directory, and plain text when they typed it. Most records will
            // be plain text, and that is fine — a record without a garage page
            // is a complete record.
            Row(
              children: [
                Flexible(
                  child: Text(
                    '${_dateOf(record.date)} · ${_thousands(record.km)} ק"מ'
                    '${record.placeId == null && record.garageName != null ? ' · ${record.garageName}' : ''}',
                    style: context.text.caption,
                  ),
                ),
                if (record.placeId != null && record.garageName != null)
                  Flexible(
                    child: InkWell(
                      onTap: () => context.push('/place/${record.placeId}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('· ', style: context.text.caption),
                            Flexible(
                              child: Text(
                                record.garageName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.caption.copyWith(
                                  color: colors.tealText2,
                                  decoration: TextDecoration.underline,
                                  decorationStyle: TextDecorationStyle.dotted,
                                  decorationColor: colors.tealText2,
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_left,
                                size: 14, color: colors.tealText2),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (record.notes != null && record.notes!.isNotEmpty) ...[
              const SizedBox(height: AppSpace.sm),
              Text(record.notes!, style: AppText.bodySm),
            ],
            if (record.isCorrection) ...[
              const SizedBox(height: AppSpace.sm),
              _Tag(
                text: 'תיקון לרשומה קודמת',
                color: colors.warnText,
                background: colors.warnBg,
              ),
            ],
            if (wasCorrected) ...[
              const SizedBox(height: AppSpace.sm),
              _Tag(
                text: 'נוסף תיקון לרשומה זו',
                color: colors.warnText,
                background: colors.warnBg,
              ),
            ],
            // What an editable history costs. A buyer is entitled to know
            // which entries changed after they were written, and when.
            if (record.wasEdited) ...[
              const SizedBox(height: AppSpace.sm),
              _Tag(
                text: 'עודכנה ב-${DateFormatter.format(record.editedAt!)}',
                color: colors.textMuted,
                background: colors.background,
              ),
            ],
            if (record.receiptUrl != null ||
                onCorrect != null ||
                onEdit != null) ...[
              const SizedBox(height: AppSpace.sm),
              Row(
                children: [
                  if (record.receiptUrl != null)
                    TextButton.icon(
                      icon: const Icon(Icons.receipt_long_outlined, size: 18),
                      label: const Text('קבלה'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PhotoViewer(
                            photos: [record.receiptUrl!],
                            initialIndex: 0,
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (onEdit != null)
                    TextButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      label: const Text('ערוך'),
                      onPressed: () => onEdit!(record),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(ServiceType type) => switch (type) {
        ServiceType.routine => Icons.build_outlined,
        ServiceType.repair => Icons.handyman_outlined,
        ServiceType.tires => Icons.tire_repair,
        ServiceType.brakes => Icons.disc_full_outlined,
        ServiceType.timingBelt => Icons.settings_outlined,
        ServiceType.test => Icons.fact_check_outlined,
        ServiceType.insurance => Icons.shield_outlined,
        ServiceType.other => Icons.more_horiz,
      };
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.text,
    required this.color,
    required this.background,
  });

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.xxs,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        child: Text(
          text,
          style: AppText.bodySm.copyWith(color: color),
        ),
      );
}

String _dateOf(DateTime d) => '${d.day}/${d.month}/${d.year}';

String _thousands(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
