import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_palette.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/models/car_model.dart';
import '../../data/models/seller_encounter.dart';
import '../providers/auth_provider.dart';
import '../providers/cars_provider.dart';
import '../../core/theme/app_text.dart';
import 'app_card.dart';
import 'login_required_sheet.dart';

/// "עם מי נפגשתם בקנייה?" — buyers who met the seller report whether they were
/// a private owner, an agent or a dealer. The tally (one vote per buyer) puts
/// the reliability rating literally in the buyers' hands, and flags when the
/// crowd disagrees with the listing's declared type.
class SellerEncounterCard extends ConsumerWidget {
  const SellerEncounterCard({super.key, required this.car});

  final CarModel car;

  static const _types = [
    SellerType.private,
    SellerType.agent,
    SellerType.dealer,
  ];

  (Color, Color, IconData) _style(BuildContext context, SellerType t) =>
      switch (t) {
        SellerType.private =>
          (context.colors.tealLight, context.colors.tealText2, Icons.person_outline),
        SellerType.agent =>
          (context.colors.agentBlueBg, context.colors.agentBlue, Icons.handshake_outlined),
        SellerType.dealer => (
            context.colors.dealerOrangeBg,
            context.colors.dealerOrange,
            Icons.storefront_outlined
          ),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tallyAsync = ref.watch(encounterTallyProvider(car.id));

    return AppSectionCard(
      icon: Icons.groups_outlined,
      title: 'עם מי נפגשתם בקנייה?',
      source: DataSource.community,
      subtitle:
          'האמינות בידיים שלכם — פגשתם את המוכר? דווחו מי הוא באמת. כך כל קונה הבא יודע.',
      child: tallyAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, __) => _InlineRetry(
          message: 'לא ניתן לטעון דיווחים כרגע.',
          onRetry: () => ref.invalidate(encounterTallyProvider(car.id)),
        ),
        data: (tally) => _body(context, ref, tally),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, EncounterTally tally) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tally.disagreesWith(car.sellerType))
          _AttentionBanner(
            declared: car.sellerType,
            reported: tally.majority!,
            percent: tally.percentFor(tally.majority!),
            total: tally.total,
          ),

        // Below the minimum we deliberately show no breakdown — two opinions
        // are not a pattern, and presenting them as one invites a false claim.
        if (!tally.hasEnoughReports)
          _NotEnoughInfo(total: tally.total)
        else ...[
          for (final t in _types)
            if (tally.countFor(t) > 0)
              _TallyRow(
                type: t,
                count: tally.countFor(t),
                percent: tally.percentFor(t),
                share: tally.shareFor(t),
                style: _style(context, t),
                highlight: tally.myReport == t,
              ),
          const SizedBox(height: 4),
          Text(
            [
              'מתוך ${tally.total} דיווחי משתמשים',
              if (tally.lastUpdatedLabel case final l?) l,
            ].join(' · '),
            style: context.text.micro,
          ),
        ],

        const SizedBox(height: 12),
        Text(
          tally.myReport == null
              ? 'נפגשת עם המוכר? כיצד הוא פעל?'
              : 'דיווחת. אפשר לעדכן:',
          style: context.text.caption,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in _types)
              _ReportChip(
                label: t.label,
                style: _style(context, t),
                selected: tally.myReport == t,
                onTap: () => _report(context, ref, t),
              ),
          ],
        ),

        // Required framing: this is community input, not an official record,
        // plus a route to challenge it (BUSINESS_ROADMAP 9.2 / 9.6 / 9.10).
        const SizedBox(height: 12),
        Divider(height: 1, color: context.colors.cardBorder),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 14, color: context.colors.textSubtle),
            const SizedBox(width: 5),
            Expanded(
              child: Text(AppStrings.communityDataNote, style: context.text.micro),
            ),
            if (tally.total > 0)
              TextButton(
                onPressed: () => _reportWrong(context, ref),
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.textMuted,
                  minimumSize: const Size(0, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('דווח על מידע שגוי',
                    style: TextStyle(fontSize: 11.5)),
              ),
          ],
        ),
      ],
    );
  }

  /// Lets anyone — including the seller — challenge the tally. Having a visible
  /// correction route is what keeps a crowd statistic defensible.
  Future<void> _reportWrong(BuildContext context, WidgetRef ref) async {
    final isGuest = ref.read(authStateProvider).valueOrNull == null;
    if (isGuest) {
      showLoginRequired(context, action: 'לדווח על מידע שגוי');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('לדווח על מידע שגוי?'),
        content: const Text(
            'הדיווחים כאן נמסרו על ידי משתמשים. אם הם אינם נכונים, נבדוק את הפנייה '
            'ונתקן או נסיר את המידע לפי הצורך.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ביטול')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('שלח בקשה')),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(reportEncounterTallyProvider).call(car.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('הבקשה נשלחה לבדיקה. תודה.')),
      );
    }
  }

  Future<void> _report(
      BuildContext context, WidgetRef ref, SellerType type) async {
    final isGuest = ref.read(authStateProvider).valueOrNull == null;
    if (isGuest) {
      showLoginRequired(context, action: 'לדווח מי המוכר');
      return;
    }
    await ref.read(recordEncounterProvider).call(car.id, type);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('תודה! הדיווח שלך עוזר לקונים הבאים.')),
      );
    }
  }
}

/// A single type's share of the reports, with a proportional bar.
class _TallyRow extends StatelessWidget {
  const _TallyRow({
    required this.type,
    required this.count,
    required this.percent,
    required this.share,
    required this.style,
    required this.highlight,
  });

  final SellerType type;
  final int count;
  final int percent;
  final double share;
  final (Color, Color, IconData) style;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final (_, fg, icon) = style;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          SizedBox(
            width: 64,
            child: Text(type.label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
                    color: context.colors.textPrimary)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: share,
                minHeight: 8,
                backgroundColor: context.colors.background,
                valueColor: AlwaysStoppedAnimation(fg),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Percentage leads, raw count in brackets — the figure the spec asks
          // us to state ("X% of reporters said…").
          Text('$percent%',
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.bold, color: fg)),
          const SizedBox(width: 3),
          Text('($count)', style: context.text.micro),
          if (highlight) ...[
            const SizedBox(width: 4),
            Icon(Icons.check_circle, size: 14, color: fg),
          ],
        ],
      ),
    );
  }
}

/// Tappable pill for reporting one seller type.
class _ReportChip extends StatelessWidget {
  const _ReportChip({
    required this.label,
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final (Color, Color, IconData) style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = style;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? fg : bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? fg : bg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: selected ? context.colors.onBrand : fg),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: selected ? context.colors.onBrand : fg)),
          ],
        ),
      ),
    );
  }
}

/// Drawn when most reporters named a type other than the declared one.
///
/// Wording is deliberately statistical — it attributes the claim to reporters
/// and never asserts what the seller is (BUSINESS_ROADMAP 9.1 / 9.6).
class _AttentionBanner extends StatelessWidget {
  const _AttentionBanner({
    required this.declared,
    required this.reported,
    required this.percent,
    required this.total,
  });

  final SellerType declared;
  final SellerType reported;
  final int percent;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.warnBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: context.colors.warnText),
          const SizedBox(width: 8),
          Expanded(
            // "ציינו שנפגשו עם מוכר שפעל כ…" describes the reporters' own
            // experience. Saying someone "is" a dealer labels the person.
            child: Text(
              '$percent% מהמדווחים ($total דיווחים) ציינו שנפגשו עם מוכר '
              'שפעל כ"${reported.label}", בעוד המודעה מסומנת "${declared.label}". '
              'כדאי לבדוק בעצמכם.',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.colors.warnText),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown while there are too few reports to describe a pattern.
class _NotEnoughInfo extends StatelessWidget {
  const _NotEnoughInfo({required this.total});
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(Icons.help_outline, size: 16, color: context.colors.textSubtle),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              total == 0
                  ? 'אין עדיין דיווחים על הרכב הזה.'
                  : 'אין מספיק מידע כדי להציג התפלגות '
                      '($total מתוך ${EncounterTally.minReportsToShow} דיווחים נדרשים).',
              style: context.text.micro,
            ),
          ),
        ],
      ),
    );
  }
}

/// A one-line failure with a retry beside it, for a section nested inside a
/// card. The full [ErrorRetry] block is right for a whole screen and far too
/// heavy for a footnote.
class _InlineRetry extends StatelessWidget {
  const _InlineRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Flexible(child: Text(message, style: context.text.bodySmMuted)),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('נסו שוב'),
          ),
        ],
      );
}
