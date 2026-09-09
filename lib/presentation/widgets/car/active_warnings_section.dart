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

  /// Not a finding at all — context the buyer is better off knowing.
  ///
  /// Added because a record can be worth stating without anything being wrong
  /// with it. A relisting is legal and extremely common, and the code said so
  /// twice in comments while rendering it in amber under a heading that reads
  /// "findings that need looking into". The words refused to make an
  /// accusation and the layout made it anyway.
  info,
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
  }) => ActiveWarning(
    id: 'odometer_official',
    severity: WarningSeverity.high,
    title: "אי-התאמה בקילומטראז'",
    detail:
        'המודעה מציינת ${_thousands(listedKm)} ק"מ. '
        'בטסט האחרון ($testDate) נרשמו ${_thousands(officialKm)} ק"מ.',
    actionLabel: actionLabel,
    onAction: onAction,
  );

  /// A past listing for this plate showed a higher reading than this one.
  factory ActiveWarning.odometerBelowPastListing({
    required int pastKm,
    required int currentKm,
    required String pastDate,
  }) => ActiveWarning(
    id: 'odometer_past_listing',
    severity: WarningSeverity.high,
    title: 'אי-התאמה מול מודעה קודמת',
    detail:
        'מודעה קודמת לרכב זה מ-$pastDate ציינה '
        '${_thousands(pastKm)} ק"מ. המודעה הנוכחית מציינת '
        '${_thousands(currentKm)}.',
  );

  /// The registry carries a structural-change record.
  factory ActiveWarning.structuralChange() => const ActiveWarning(
    id: 'structural_change',
    severity: WarningSeverity.medium,
    title: 'שינוי מבני',
    detail:
        'במרשם רשום שינוי מבני. '
        'מומלץ לברר את פרטיו במכון בדיקה.',
  );

  /// One or more manufacturer recalls are still open on this plate.
  factory ActiveWarning.openRecall({required int count}) => ActiveWarning(
    id: 'open_recall',
    severity: WarningSeverity.high,
    title: count == 1 ? 'קריאת שירות פתוחה' : '$count קריאות שירות פתוחות',
    // What the dataset records is that a recall is open — not who pays,
    // on what terms, or whether this importer honours it on a car of this
    // age. Promising a free repair on a third party's behalf is a
    // guarantee the app cannot stand behind.
    detail:
        'תיקון בקריאת שירות מבוצע אצל היבואן — '
        'כדאי לברר מולו את התנאים.',
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
  }) => ActiveWarning(
    id: 'also_listed_now',
    // Medium, not high. `high` is defined above as contradicting an
    // official record or costing money to put right, and a duplicate
    // listing does neither — its own text says "worth asking about", which
    // is the definition of medium. The commonest cause is a stale advert
    // nobody took down; rendering that in the same red as an odometer
    // rollback characterises it by colour.
    severity: WarningSeverity.medium,
    // "The same plate appears", not "the vehicle is listed". What the app
    // knows is that another live listing carried the same plate string — a
    // mistyped plate produces an identical record.
    title:
        count == 1
            ? 'אותה לוחית מופיעה גם במודעה נוספת'
            : 'אותה לוחית מופיעה גם ב-$count מודעות נוספות',
    // Not "which of them is current": that presupposes one is stale, and
    // two listings for one car can both be live — the same car
    // cross-posted, or a seller running two channels. (The old phrasing
    // was also ungrammatical: `אילו` is plural, `עדכנית` singular.)
    detail:
        'מודעה פעילה נוספת על אותה לוחית מציינת '
        '‎₪$otherPrice‏, $otherArea. '
        'כדאי לברר מול המוכר את הקשר בין המודעות.',
  );

  /// The same plate ran recently under a different kind of seller.
  ///
  /// Context, not a warning about the seller: buying a car and reselling it is
  /// a legal business, and an owner who moves to a dealer is not a finding.
  ///
  /// **No price.** `PlateHistoryCard` states the rule this used to break, in
  /// the code, on the same screen: past listings are summarised and never
  /// itemised, because a date joined to an exact asking price builds a
  /// timeline of who owned the car and what they paid. Recency and the change
  /// of seller type carry the buyer's actual signal without publishing that.
  ///
  /// **And "a different kind of seller", not "a different seller".**
  /// `RelistingCheck.recentSellerChange` compares `sellerType` only, and
  /// `PlateSnapshot` deliberately stores no seller identity — so an owner who
  /// relists through an agent is the same person the app has just called
  /// somebody else.
  factory ActiveWarning.soldOnRecently({
    required String pastSeller,
    required String pastDate,
  }) => ActiveWarning(
    id: 'sold_on_recently',
    severity: WarningSeverity.info,
    title: 'מודעה קודמת פורסמה בסוג מוכר אחר',
    detail:
        'ב-$pastDate פורסמה על אותה לוחית מודעה בסוג מוכר '
        '$pastSeller. פרסום מחדש של רכב הוא נפוץ וחוקי.',
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

  /// The quiet half. Things worth knowing that nobody has to act on.
  static const contextHeading = 'הקשר נוסף';

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) return const SizedBox.shrink();

    // Two blocks, because one heading cannot honestly cover both. An
    // informational record filed under "findings that need looking into" is
    // accused by its surroundings however carefully its own sentence is
    // written.
    final findings = [
      for (final w in warnings)
        if (w.severity != WarningSeverity.info) w,
    ];
    final context_ = [
      for (final w in warnings)
        if (w.severity == WarningSeverity.info) w,
    ];

    // The block sat flush against the car title with no gap at all. The
    // notice directly above it on the same page wraps itself the same way,
    // rather than making every caller remember to.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (findings.isNotEmpty)
            _Block(
              heading: heading,
              icon: Icons.error_outline,
              tone: context.colors.warnText,
              warnings: findings,
            ),
          if (findings.isNotEmpty && context_.isNotEmpty)
            const SizedBox(height: AppSpace.lg),
          if (context_.isNotEmpty)
            _Block(
              heading: contextHeading,
              icon: Icons.info_outline,
              tone: context.colors.textMuted,
              warnings: context_,
            ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.heading,
    required this.icon,
    required this.tone,
    required this.warnings,
  });

  final String heading;
  final IconData icon;
  final Color tone;
  final List<ActiveWarning> warnings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: tone),
            const SizedBox(width: AppSpace.sm - 2),
            Expanded(
              child: Text(
                heading,
                style: AppText.subtitle.copyWith(color: tone),
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
    final severity = warning.severity;

    // Fill for high, outline for medium, nothing for context. Severity is
    // carried by weight rather than by a second hue, so the page keeps one
    // warning colour and the ranking still reads at a glance.
    final background = switch (severity) {
      WarningSeverity.high => colors.errorBg,
      WarningSeverity.medium => Colors.transparent,
      WarningSeverity.info => Colors.transparent,
    };
    final border = switch (severity) {
      WarningSeverity.high => colors.errorRed.withValues(alpha: 0.32),
      WarningSeverity.medium => colors.warnText.withValues(alpha: 0.34),
      WarningSeverity.info => colors.cardBorder,
    };
    // The high title used to be `errorRed` on `errorBg` — 2.98:1 in the light
    // theme, under this project's own 3:1 floor for text this size. The
    // loudest finding on the page was its least legible line, in the default
    // theme. The fill and the red border carry the severity; the words are
    // there to be read.
    final titleColor = switch (severity) {
      WarningSeverity.high => colors.textPrimary,
      WarningSeverity.medium => colors.warnText,
      WarningSeverity.info => colors.textMuted,
    };

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
