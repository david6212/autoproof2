import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/insurance_renewal.dart';
import '../../../data/models/vehicle_reminder.dart';
import '../../providers/vehicle_provider.dart';
import '../add_reminder_sheet.dart';
import '../app_card.dart';

/// Asks the owner when their insurance runs out, once, and then never again.
///
/// **The app cannot work this out.** A licence expiry is a public fact in the
/// vehicle registry and the test reminder is created from it automatically. An
/// insurance policy is a private contract; no government dataset knows when it
/// ends, so the only honest way to have the date is to ask for it.
///
/// Which is why this exists at all. Insurance was already an option in the
/// add-reminder sheet, and an owner who never opened that sheet never got a
/// reminder — for the one renewal where forgetting is not an inconvenience but
/// an uninsured car on the road. The feature was not missing; the question was.
///
/// It disappears the moment there is an insurance reminder, done or not. A card
/// that keeps asking after it has been answered is nagging, and nagging is how
/// a prompt gets dismissed without being read.
class InsurancePrompt extends ConsumerWidget {
  const InsurancePrompt({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(vehicleRemindersProvider(vehicleId));
    // Silent while the reminders load. Asking a question the owner has already
    // answered, for the second it takes a stream to arrive, is worse than a
    // beat of nothing.
    if (!reminders.hasValue) return const SizedBox.shrink();

    final has = reminders.value!.any((r) => r.type == ReminderType.insurance);
    if (has) return const SizedBox.shrink();

    final services =
        ref.watch(vehicleServicesProvider(vehicleId)).valueOrNull ?? const [];
    final expenses =
        ref.watch(vehicleExpensesProvider(vehicleId)).valueOrNull ?? const [];
    final suggestion = InsuranceRenewal.suggest(
      services: services,
      expenses: expenses,
      now: DateTime.now(),
    );

    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 18, color: colors.tealText2),
                const SizedBox(width: AppSpace.sm),
                const Text('מתי מסתיים הביטוח?', style: AppText.subtitle),
              ],
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              // Says why it is asking. A form that explains itself gets filled
              // in; one that just demands a date gets closed.
              'תוקף הביטוח לא מופיע במרשם הרכב — הוא חוזה פרטי שלכם מול חברת '
              'הביטוח, ואנחנו לא יכולים לדעת מתי הוא נגמר. אם תגידו לנו, '
              'נזכיר לכם ${InsuranceRenewal.leadDays} יום מראש, בזמן להשוות הצעות.',
              style: AppText.bodySm.copyWith(color: colors.textMuted),
            ),

            if (suggestion != null) ...[
              const SizedBox(height: AppSpace.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpace.sm),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  border: Border.all(color: colors.cardBorder),
                ),
                child: Text(
                  // Marked as a guess in the sentence itself, not only by
                  // being editable afterwards. Israeli motor policies run a
                  // year, so the last premium the owner recorded points at
                  // roughly when the next one falls due — roughly.
                  'רשמתם תשלום ביטוח, ולפי שנה מאז זה יוצא בערך '
                  '${DateFormatter.format(suggestion)}. אפשר לשנות.',
                  style: context.text.caption,
                ),
              ),
            ],

            const SizedBox(height: AppSpace.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.event_outlined, size: 18),
                label: const Text('הגדרת תזכורת ביטוח'),
                onPressed: () => AddReminderSheet.show(
                  context,
                  vehicleId,
                  initialType: ReminderType.insurance,
                  initialDate: suggestion,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
