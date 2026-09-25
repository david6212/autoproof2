import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import '../../data/models/vehicle.dart';
import 'app_card.dart';

/// How close this car is to "תיק מתועד", shown as progress rather than as a
/// list of what is missing.
///
/// The order of the words is the whole design. "לתג חסרים עוד 2 רשומות" opens
/// on a deficit and reads as a demand; "רשומה אחת מתוך 3" opens on something
/// the owner already did and reads as a count they can finish. Same two
/// numbers, and the second is the one people act on.
///
/// **After the badge is earned it does not disappear — it starts counting
/// depth.** People keep cars for years, and the app wants those years
/// documented: a meter that vanished at three records taught the owner that
/// three was the finish line. Earned, it shows what the file actually holds —
/// "12 רשומות · 4 שנים" — which is also what makes the badge worth more on one
/// listing than on another.
///
/// What it must never do is inflate. Both figures are counted from records
/// that exist, the bar tracks the half that is further behind, and a car with
/// nothing logged shows an empty bar rather than a free first step. A buyer's
/// only reason to trust the badge is that it cannot be performed, and this
/// widget sits directly upstream of that.
class DocumentedProgressMeter extends StatelessWidget {
  const DocumentedProgressMeter({
    super.key,
    required this.progress,
    this.compact = false,
  });

  final DocumentedProgress progress;

  /// One line and a bar, for the garage list. The full form adds a heading and
  /// a row per half, and belongs on the vehicle's own page.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Cars with nothing logged get the empty state's invitation, which
    // explains what the badge is for; a meter reading zero would say less.
    if (!progress.started) return const SizedBox.shrink();

    if (progress.earned) return _buildEarned(context);

    return compact ? _buildCompact(context) : _buildFull(context);
  }

  /// Earned: the file's depth, and an invitation to keep adding to it.
  ///
  /// Deliberately not a bar. A bar implies a ceiling, and there is none — the
  /// records are unlimited, in the code and in the rules, and a car kept for
  /// a decade should read as a decade.
  Widget _buildEarned(BuildContext context) {
    final colors = context.colors;

    final line = Row(
      children: [
        Icon(Icons.workspace_premium, size: 18, color: colors.tealText2),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Text(
            'תיק מתועד · ${progress.depthLabel}',
            style: AppText.bodySm.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.tealText2,
            ),
          ),
        ),
      ],
    );

    if (compact) return line;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line,
            const SizedBox(height: AppSpace.sm),
            Text(
              'כל טיפול שתוסיפו נשמר בתיק ומוצג לקונה. אין הגבלה על מספר '
              'הרשומות, וככל שהתיעוד ארוך יותר הוא שווה יותר.',
              style: context.text.micro,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Bar(fraction: progress.fraction),
        const SizedBox(height: AppSpace.sm),
        Text(
          'בדרך ל"תיק מתועד" · ${_recordsLabel()} · ${_monthsLabel()}',
          style: context.text.caption,
        ),
      ],
    );
  }

  Widget _buildFull(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.workspace_premium_outlined,
                    size: 20, color: colors.teal),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Text('בדרך ל"תיק מתועד"',
                      style: AppText.bodySm
                          .copyWith(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            _Bar(fraction: progress.fraction),
            const SizedBox(height: AppSpace.md),
            _Half(label: 'רשומות', value: _recordsLabel()),
            const SizedBox(height: AppSpace.xs),
            const SizedBox(height: AppSpace.xs),
            _Half(label: 'תיעוד לאורך זמן', value: _monthsLabel()),
            const SizedBox(height: AppSpace.sm),
            Text(
              '${_remainingSentence()}. זה המינימום לתג — אפשר להמשיך לתעד '
              'כמה שתרצו, וכל רשומה נוספת נשארת בתיק.',
              style: context.text.micro,
            ),
          ],
        ),
      ),
    );
  }

  String _recordsLabel() =>
      '${progress.records} מתוך ${Vehicle.documentedMinRecords} רשומות';

  String _monthsLabel() =>
      '${progress.months} מתוך ${Vehicle.documentedMinMonths} חודשים';

  /// The deficit, kept as a quiet closing line rather than the headline.
  ///
  /// It still has to be here — an owner with 3 records and 2 months would
  /// otherwise have no way to learn that more receipts will not help, only
  /// time will.
  String _remainingSentence() {
    final parts = <String>[
      if (progress.recordsNeeded > 0)
        progress.recordsNeeded == 1
            ? 'רשומה אחת'
            : '${progress.recordsNeeded} רשומות',
      if (progress.monthsNeeded > 0)
        progress.monthsNeeded == 1
            ? 'חודש אחד'
            : '${progress.monthsNeeded} חודשים',
    ];
    return 'נותרו ${parts.join(' ו')}';
  }
}

/// The bar itself. Rounded, thin, and tinted teal — the same green that means
/// "official" elsewhere, because this measures records rather than opinion.
class _Bar extends StatelessWidget {
  const _Bar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: LinearProgressIndicator(
        value: fraction,
        minHeight: 6,
        backgroundColor: colors.background,
        valueColor: AlwaysStoppedAnimation<Color>(colors.teal),
      ),
    );
  }
}

class _Half extends StatelessWidget {
  const _Half({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: context.text.caption)),
        Text(value, style: context.text.captionBold),
      ],
    );
  }
}
