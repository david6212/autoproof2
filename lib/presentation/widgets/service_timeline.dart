import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import '../../data/models/service_record.dart';
import 'app_card.dart';
import 'photo_viewer.dart';

/// A vehicle's service history, newest first.
///
/// **There is no edit button and no delete button here, and that is the
/// feature.** The only way to change what the timeline says is [onCorrect],
/// which adds a record; the wrong entry stays visible with the correction
/// linked to it. If a future change adds a delete action to this widget, the
/// history stops being evidence and the "תיק מתועד" badge stops meaning
/// anything.
///
/// [onCorrect] is null in the buyer's view — a buyer reads the history, they
/// do not write to it.
class ServiceTimeline extends StatelessWidget {
  const ServiceTimeline({
    super.key,
    required this.records,
    this.onCorrect,
    this.showFooter = true,
  });

  final List<ServiceRecord> records;
  final void Function(ServiceRecord record)? onCorrect;

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
          ),
        if (showFooter) ...[
          const SizedBox(height: AppSpace.md),
          Text(
            'רשומות טיפול אינן ניתנות לעריכה או מחיקה לאחר הזנתן. '
            'הן הוזנו על ידי בעל הרכב ולא אומתו על ידי BonnetCheck.',
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
  });

  final ServiceRecord record;
  final bool wasCorrected;
  final void Function(ServiceRecord record)? onCorrect;

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
            Text(
              '${_dateOf(record.date)} · ${_thousands(record.km)} ק"מ'
              '${record.garageName != null ? ' · ${record.garageName}' : ''}',
              style: context.text.caption,
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
            if (record.receiptUrl != null || onCorrect != null) ...[
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
                  // The stand-in for "edit". It writes a new record; it cannot
                  // touch this one.
                  if (onCorrect != null)
                    TextButton(
                      onPressed: () => onCorrect!(record),
                      child: const Text('הוסף תיקון'),
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
