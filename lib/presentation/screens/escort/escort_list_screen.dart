import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../data/models/escort_pro.dart';
import '../../providers/escort_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/escort_verification_chip.dart';
import '../../widgets/glass.dart';

/// People who will come with a buyer to look at a car.
///
/// **The screen is a directory, not a recommendation.** Nothing here is ranked
/// by us: the order is newest first, the rating comes from buyers who used
/// somebody, and a professional who proved nothing about themselves is listed
/// beside one the register knows — with the difference written on both.
class EscortListScreen extends ConsumerStatefulWidget {
  const EscortListScreen({super.key});

  @override
  ConsumerState<EscortListScreen> createState() => _EscortListScreenState();
}

class _EscortListScreenState extends ConsumerState<EscortListScreen> {
  String? _area;

  @override
  Widget build(BuildContext context) {
    final prosAsync = ref.watch(escortProsProvider(_area));

    return Scaffold(
      appBar: AppBar(
        title: const Text('ליווי לבדיקת רכב'),
        actions: [
          TextButton(
            onPressed: () => context.push('/escort/join'),
            child: const Text('אני בעל מקצוע'),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: prosAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const _Empty(
            title: 'לא הצלחנו לטעון את הרשימה',
            body: 'בדקו את החיבור ונסו שוב.',
          ),
          data: (pros) {
            if (pros.isEmpty) {
              return const _Empty(
                title: 'אין עדיין בעלי מקצוע באזור הזה',
                body: 'הרשימה נבנית ממי שנרשם. אם אתם מכירים מכונאי שהיה '
                    'מלווה קונים, שלחו לו את האפליקציה.',
              );
            }

            return ListView.separated(
              padding: EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md,
                  AppSpace.lg, AppSpace.xl + navClearance(context)),
              itemCount: pros.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpace.md),
              itemBuilder: (context, i) {
                if (i == 0) return const _Intro();
                return _ProCard(pro: pros[i - 1]);
              },
            );
          },
        ),
      ),
    );
  }
}

/// What this list is, before the first card. Two sentences, because a reader
/// who does not know what they are looking at cannot judge the chips below.
class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Text(
        'בעלי מקצוע שמציעים לבוא איתכם לראות רכב, במחיר שהם קובעים. '
        'ליד כל אחד כתוב מה נבדק לגביו ומה לא.',
        style: context.text.bodyMuted,
      ),
    );
  }
}

class _ProCard extends StatelessWidget {
  const _ProCard({required this.pro});

  final EscortPro pro;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppCard(
      onTap: () => context.push('/escort/${pro.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pro.displayName, style: AppText.title),
                    const SizedBox(height: 2),
                    Text(
                      [
                        pro.town,
                        if (pro.yearsExperience > 0)
                          '${pro.yearsExperience} שנות ניסיון',
                      ].join(' · '),
                      style: context.text.micro,
                    ),
                  ],
                ),
              ),
              Text(MoneyFormatter.format(pro.priceIls), style: AppText.title),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          EscortVerificationChip(
            verification: pro.verification,
            detail: pro.verificationDetail,
          ),
          // The rating stays hidden under three opinions, exactly as it does
          // on a garage: two people liking somebody is not a score.
          if (pro.hasEnoughRatings) ...[
            const SizedBox(height: AppSpace.sm),
            Row(
              children: [
                Icon(Icons.star, size: 14, color: colors.starColor),
                const SizedBox(width: AppSpace.xs),
                Text(
                  '${pro.ratingAvg.toStringAsFixed(1)} · ${pro.ratingCount} ליווים',
                  style: context.text.micro,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.handshake_outlined,
                size: 48, color: context.colors.teal),
            const SizedBox(height: AppSpace.lg),
            Text(title, style: AppText.h3, textAlign: TextAlign.center),
            const SizedBox(height: AppSpace.sm),
            Text(body,
                style: context.text.bodyMuted, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
