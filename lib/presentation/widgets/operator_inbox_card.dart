import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/repositories/operator_inbox_repository.dart';
import '../providers/operator_inbox_provider.dart';
import '../providers/place_provider.dart';
import 'app_card.dart';

/// The requests the operator has fourteen days to answer.
///
/// **Shown only to the operator, and only because there is no server to email
/// them.** The published privacy, removal and complaints documents all promise
/// an answer within fourteen days; until now both collections behind that
/// sentence were unreadable by everybody, so the promise had no delivery at
/// all. On the Spark plan the delivery is this: the operator opens the app, and
/// the requests are on the screen they open.
///
/// Invisible to everyone else — not hidden behind a password, simply not built.
/// Anyone who forged their way to this widget would still be refused by the
/// rules, which check the same account and the same verified email.
class OperatorInboxCard extends ConsumerWidget {
  const OperatorInboxCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isOperatorProvider)) return const SizedBox.shrink();

    final items = ref.watch(operatorInboxProvider);
    final colors = context.colors;
    final now = DateTime.now();

    return items.when(
      loading: () => const SizedBox.shrink(),
      // Silent on failure rather than showing an error to the one person who
      // can already see it in the console. A red box on the profile screen for
      // a transient stream error would be worse than a beat of nothing.
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        final urgent = list.where((i) => i.isUrgent(now)).length;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.lg),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 18,
                        color: urgent > 0 ? colors.errorRed : colors.tealText2),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Text(
                        list.isEmpty
                            ? 'אין פניות ממתינות'
                            : 'פניות ממתינות: ${list.length}',
                        style: AppText.subtitle,
                      ),
                    ),
                    if (urgent > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.sm, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.errorBg,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          '$urgent מעל שבוע',
                          style: context.text.micro
                              .copyWith(color: colors.errorRed),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  // Says the number out loud rather than "handle these soon".
                  // The commitment is what makes the list urgent, and a
                  // reminder that does not name it is just a badge.
                  'המסמכים שפרסמתם מבטיחים מענה תוך 14 יום.',
                  style: context.text.micro,
                ),

                if (list.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.md),
                  for (final item in list.take(6)) ...[
                    _Row(item: item, now: now),
                    if (item != list.take(6).last)
                      Divider(height: AppSpace.lg, color: colors.cardBorder),
                  ],
                  if (list.length > 6) ...[
                    const SizedBox(height: AppSpace.sm),
                    Text('ועוד ${list.length - 6}.', style: context.text.micro),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.item, required this.now});

  final InboxItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final days = item.daysWaiting(now);
    final urgent = item.isUrgent(now);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(item.kind.label, style: AppText.bodySm),
                  const SizedBox(width: AppSpace.sm),
                  Text(
                    days == null
                        ? 'זה עתה'
                        : days == 0
                            ? 'היום'
                            : 'לפני $days ימים',
                    style: context.text.micro.copyWith(
                        color: urgent ? colors.errorRed : colors.textSubtle),
                  ),
                ],
              ),
              if (item.note != null && item.note!.trim().isNotEmpty)
                Text(
                  item.note!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.micro,
                ),
              if (item.createdAt != null)
                Text(DateFormatter.format(item.createdAt!),
                    style: context.text.micro),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // A review report can be acted on from here, without hunting for
            // the garage: hide the review, and close the report, in one tap.
            // Hiding never deletes — the words stay, so a report that turns
            // out to be wrong is undone from the garage's page.
            if (item.kind == InboxKind.reviewReport &&
                item.placeId != null &&
                item.reviewUid != null)
              TextButton(
                onPressed: () async {
                  await ref.read(placeRepositoryProvider).hideReview(
                        placeId: item.placeId!,
                        reviewUid: item.reviewUid!,
                      );
                  await ref
                      .read(operatorInboxRepositoryProvider)
                      .markHandled(item);
                },
                style: TextButton.styleFrom(
                  foregroundColor: colors.errorRed,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
                ),
                child: const Text('הסתר וסגור', style: TextStyle(fontSize: 12.5)),
              ),
            TextButton(
              onPressed: () =>
                  ref.read(operatorInboxRepositoryProvider).markHandled(item),
              style: TextButton.styleFrom(
                foregroundColor: colors.tealText2,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
              ),
              child: const Text('טופל', style: TextStyle(fontSize: 12.5)),
            ),
          ],
        ),
      ],
    );
  }
}
