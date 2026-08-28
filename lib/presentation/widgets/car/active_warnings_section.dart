import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';

/// How far a finding outranks the rest of the page.
enum WarningSeverity {
  /// Contradicts an official record, or costs money to put right.
  high,

  /// Worth asking about before money changes hands.
  medium,
}

/// One thing on this listing that does not add up.
class ActiveWarning {
  const ActiveWarning({
    required this.id,
    required this.severity,
    required this.title,
    required this.detail,
    this.actionLabel,
    this.onAction,
  });

  final String id;
  final WarningSeverity severity;

  /// What the finding is, in three or four words.
  final String title;

  /// The finding itself, carrying the actual numbers and dates. Never a
  /// characterisation of them — the reader draws the conclusion.
  final String detail;

  final String? actionLabel;
  final VoidCallback? onAction;

  // ---- the five findings the app can actually produce ------------------
  //
  // Kept together so the wording is written once and reviewed as a set.
  // Every one of them states records and leaves the reading to the buyer:
  // none says "suspicious", none says "fake", none ends in an exclamation
  // mark. A seller who typed a number wrong and a seller who rolled a
  // clock back produce the identical record, and we cannot tell them apart.

  /// The odometer on the listing is behind the last official test reading.
  factory ActiveWarning.odometerBelowOfficial({
    required int listedKm,
    required int officialKm,
    required String testDate,
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      ActiveWarning(
        id: 'odometer_official',
        severity: WarningSeverity.high,
        title: "אי-התאמה בקילומטראז'",
        detail: 'המודעה מציינת ${_thousands(listedKm)} ק"מ. '
            'בטסט האחרון ($testDate) נרשמו ${_thousands(officialKm)} ק"מ.',
        actionLabel: actionLabel,
        onAction: onAction,
      );

  /// A past listing for this plate showed a higher reading than this one.
  factory ActiveWarning.odometerBelowPastListing({
    required int pastKm,
    required int currentKm,
    required String pastDate,
  }) =>
      ActiveWarning(
        id: 'odometer_past_listing',
        severity: WarningSeverity.high,
        title: 'אי-התאמה מול מודעה קודמת',
        detail: 'מודעה קודמת לרכב זה מ-$pastDate ציינה '
            '${_thousands(pastKm)} ק"מ. המודעה הנוכחית מציינת '
            '${_thousands(currentKm)}.',
      );

  /// The registry carries a structural-change record.
  factory ActiveWarning.structuralChange() => const ActiveWarning(
        id: 'structural_change',
        severity: WarningSeverity.medium,
        title: 'שינוי מבני',
        detail: 'במרשם רשום שינוי מבני. '
            'מומלץ לברר את פרטיו במכון בדיקה.',
      );

  /// One or more manufacturer recalls are still open on this plate.
  factory ActiveWarning.openRecall({required int count}) => ActiveWarning(
        id: 'open_recall',
        severity: WarningSeverity.high,
        title: count == 1
            ? 'קריאת שירות פתוחה'
            : '$count קריאות שירות פתוחות',
        detail: 'התיקון מבוצע ללא עלות בסוכנות מורשית.',
      );

  /// The same plate is on the market in more than one listing right now.
  ///
  /// Deliberately does not say which one is wrong, because the app cannot
  /// know. A seller who forgot to take an old listing down and a seller
  /// running two at once produce an identical record.
  factory ActiveWarning.alsoListedNow({
    required int count,
    required String otherPrice,
    required String otherArea,
  }) =>
      ActiveWarning(
        id: 'also_listed_now',
        severity: WarningSeverity.high,
        title: count == 1
            ? 'הרכב מפורסם גם במודעה נוספת'
            : 'הרכב מפורסם גם ב-$count מודעות נוספות',
        detail: 'מודעה פעילה נוספת על אותה לוחית מציינת '
            '‎₪$otherPrice‏, $otherArea. כדאי לברר מול המוכר אילו מהן עדכנית.',
      );

  /// The same plate ran recently under a different kind of seller.
  ///
  /// Informational, not a warning about the seller: buying a car and reselling
  /// it is a legal business. What a buyer gains is the earlier number.
  factory ActiveWarning.soldOnRecently({
    required String pastSeller,
    required String pastPrice,
    required String pastDate,
  }) =>
      ActiveWarning(
        id: 'sold_on_recently',
        severity: WarningSeverity.medium,
        title: 'הרכב פורסם לאחרונה על ידי מוכר אחר',
        detail: 'ב-$pastDate הוא פורסם על ידי $pastSeller '
            'ב-‎₪$pastPrice‏.',
      );

  /// The vehicle's registration was cancelled.
  factory ActiveWarning.offRoad() => const ActiveWarning(
        id: 'off_road',
        severity: WarningSeverity.high,
        title: 'ירידה מהכביש',
        detail: 'רישום הרכב בוטל במרשם.',
      );

  static String _thousands(int n) => n.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (m) => '${m[1]},',
      );
}

/// Everything on this listing that does not add up, gathered at the top.
///
/// The same facts used to be spread across three panels in three different
/// places on a page of seventeen — the odometer check two thirds of the way
/// down, the seller-type disagreement below that. A buyer scrolling quickly
/// could miss the one thing that should have stopped them.
///
/// Two rules govern the copy, and both come from the same place: this app
/// reports records, it does not appraise cars.
///
/// **Findings, not verdicts.** "המודעה מציינת 82,000 ק"מ. בטסט האחרון נרשמו
/// 94,300 ק"מ" is something we can stand behind. "ייתכן שהקילומטראז' זויף"
/// is an accusation we cannot, about a seller who may simply have typed a
/// number wrong.
///
/// **Nothing when there is nothing.** An empty list renders no widget at all —
/// not a green tick, not "no problems found". Absence of a record is not a
/// clean bill of health, and drawing it as one would be the single most
/// damaging claim the app could make.
class ActiveWarningsSection extends StatelessWidget {
  const ActiveWarningsSection({super.key, required this.warnings});

  final List<ActiveWarning> warnings;

  /// Deliberately "findings that need looking into" rather than "warnings".
  /// A warning is a conclusion; a finding is a record that disagrees with
  /// another record, which is all we actually have.
  static const heading = 'ממצאים שדורשים בירור';

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.error_outline, size: 18, color: colors.warnText),
            const SizedBox(width: AppSpace.sm - 2),
            Expanded(
              child: Text(
                heading,
                style: AppText.subtitle.copyWith(color: colors.warnText),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        for (final warning in warnings) ...[
          _WarningTile(warning: warning),
          if (warning != warnings.last) const SizedBox(height: AppSpace.sm),
        ],
      ],
    );
  }
}

class _WarningTile extends StatelessWidget {
  const _WarningTile({required this.warning});

  final ActiveWarning warning;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final high = warning.severity == WarningSeverity.high;

    // Fill for high, outline for medium. Severity is carried by weight rather
    // than by a second hue, so the page keeps one warning colour and the
    // ranking still reads at a glance.
    final background = high ? colors.errorBg : Colors.transparent;
    final border = high
        ? colors.errorRed.withValues(alpha: 0.32)
        : colors.warnText.withValues(alpha: 0.34);
    final titleColor = high ? colors.errorRed : colors.warnText;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            warning.title,
            style: AppText.bodySm.copyWith(
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          const SizedBox(height: AppSpace.xxs),
          Text(
            warning.detail,
            style: AppText.bodySm.copyWith(color: colors.textPrimary),
          ),
          if (warning.actionLabel != null && warning.onAction != null) ...[
            const SizedBox(height: AppSpace.xs),
            InkWell(
              onTap: warning.onAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
                child: Text(
                  warning.actionLabel!,
                  style: AppText.bodySm.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.tealText2,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
