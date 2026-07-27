import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/car_model.dart';
import '../../data/models/seller_encounter.dart';
import '../providers/auth_provider.dart';
import '../providers/cars_provider.dart';
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

  (Color, Color, IconData) _style(SellerType t) => switch (t) {
        SellerType.private =>
          (AppColors.tealLight, AppColors.tealText2, Icons.person_outline),
        SellerType.agent =>
          (AppColors.agentBlueBg, AppColors.agentBlue, Icons.handshake_outlined),
        SellerType.dealer => (
            AppColors.dealerOrangeBg,
            AppColors.dealerOrange,
            Icons.storefront_outlined
          ),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tallyAsync = ref.watch(encounterTallyProvider(car.id));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.groups_outlined, size: 18, color: AppColors.teal),
              SizedBox(width: 6),
              Text('עם מי נפגשתם בקנייה?',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
              'האמינות בידיים שלכם — פגשתם את המוכר? דווחו מי הוא באמת. כך כל קונה הבא יודע.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          const SizedBox(height: 12),
          tallyAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, __) => const Text('לא ניתן לטעון דיווחים כרגע.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            data: (tally) => _body(context, ref, tally),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, EncounterTally tally) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tally.disagreesWith(car.sellerType))
          _MismatchBanner(
            declared: car.sellerType,
            crowd: tally.majority!,
          ),
        if (tally.total > 0) ...[
          for (final t in _types)
            if (tally.countFor(t) > 0)
              _TallyRow(
                type: t,
                count: tally.countFor(t),
                total: tally.total,
                style: _style(t),
                highlight: tally.myReport == t,
              ),
          const SizedBox(height: 4),
          Text(
            tally.total == 1
                ? 'קונה אחד דיווח.'
                : '${tally.total} קונים דיווחו.',
            style: const TextStyle(fontSize: 11.5, color: AppColors.textSubtle),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          tally.myReport == null
              ? 'נפגשת עם המוכר? מי הוא היה?'
              : 'דיווחת. אפשר לעדכן:',
          style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in _types)
              _ReportChip(
                label: t.label,
                style: _style(t),
                selected: tally.myReport == t,
                onTap: () => _report(context, ref, t),
              ),
          ],
        ),
      ],
    );
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
    required this.total,
    required this.style,
    required this.highlight,
  });

  final SellerType type;
  final int count;
  final int total;
  final (Color, Color, IconData) style;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final (_, fg, icon) = style;
    final fraction = total == 0 ? 0.0 : count / total;
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
                    color: AppColors.textPrimary)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor: AppColors.background,
                valueColor: AlwaysStoppedAnimation(fg),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$count',
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.bold, color: fg)),
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
            Icon(icon, size: 15, color: selected ? AppColors.white : fg),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: selected ? AppColors.white : fg)),
          ],
        ),
      ),
    );
  }
}

/// Shown when the crowd's majority report differs from the declared type.
class _MismatchBanner extends StatelessWidget {
  const _MismatchBanner({required this.declared, required this.crowd});

  final SellerType declared;
  final SellerType crowd;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warnBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.report_gmailerrorred,
              size: 18, color: AppColors.warnText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'המודעה מסומנת "${declared.label}", אך קונים דיווחו על "${crowd.label}". בדקו טוב מי מולכם.',
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warnText),
            ),
          ),
        ],
      ),
    );
  }
}
