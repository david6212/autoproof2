import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../data/models/escort_pro.dart';
import '../../providers/escort_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/escort_verification_chip.dart';
import '../../widgets/login_required_sheet.dart';
import '../../providers/auth_provider.dart';

/// One professional, and everything known and not known about them.
///
/// The page is ordered by what a buyer decides with: who this is and what was
/// checked, what the ליווי includes, what other buyers said, then the limits —
/// and only then the button. The limits sit **above** the button on purpose:
/// a caveat read after the decision is a caveat that was never read.
class EscortProfileScreen extends ConsumerWidget {
  const EscortProfileScreen({super.key, required this.proId});

  final String proId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proAsync = ref.watch(escortProProvider(proId));

    return Scaffold(
      appBar: AppBar(title: const Text('בעל מקצוע')),
      body: SafeArea(
        child: proAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ErrorRetry(
            message: 'לא הצלחנו לטעון את הפרופיל',
            onRetry: () => ref.invalidate(escortProProvider(proId)),
          ),
          data: (pro) {
            if (pro == null) {
              return const Center(child: Text('הפרופיל לא נמצא'));
            }
            return _Content(pro: pro);
          },
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.pro});

  final EscortPro pro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xxl),
      children: [
        AppCard(
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
                        Text(pro.displayName, style: AppText.h2),
                        const SizedBox(height: 2),
                        Text(
                          [
                            pro.town,
                            if (pro.areas.isNotEmpty) pro.areas.join(', '),
                          ].join(' · '),
                          style: context.text.micro,
                        ),
                      ],
                    ),
                  ),
                  Text(MoneyFormatter.format(pro.priceIls), style: AppText.h3),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              EscortVerificationChip(
                verification: pro.verification,
                detail: pro.verificationDetail,
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                switch (pro.verification) {
                  EscortVerification.registryListed =>
                    'מספר הרישיון נמצא במרשם המוסכים של משרד התחבורה. '
                        'הבדיקה היא של מספר הרישיון בלבד — לא של זהות האדם '
                        'ולא של איכות עבודתו.',
                  EscortVerification.certificateChecked =>
                    'תעודה שהוצגה לנו ונבדקה בעיניים. איננו מאמתים זהות, '
                        'ואיננו אחראים לתוכן התעודה או לאיכות העבודה.',
                  EscortVerification.selfDeclared =>
                    'לא הוצגה תעודה ולא נמצא רישיון מוסך. כל מה שכתוב כאן '
                        'הוא מה שבעל המקצוע מסר על עצמו.',
                },
                style: context.text.micro,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),

        if (pro.about.trim().isNotEmpty) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('מה כולל הליווי', style: AppText.subtitle),
                const SizedBox(height: AppSpace.sm),
                Text(pro.about, style: AppText.body),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
        ],

        if (pro.declaresInsurance) ...[
          AppCard(
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: colors.tealText2),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    'בעל המקצוע מצהיר שיש לו ביטוח אחריות מקצועית. '
                    'לא ראינו פוליסה.',
                    style: context.text.micro,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
        ],

        const EscortLiabilityNote(),
        const SizedBox(height: AppSpace.md),

        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: colors.tealFill,
            minimumSize: const Size.fromHeight(50),
          ),
          icon: const Icon(Icons.chat_bubble_outline),
          label: Text('פנו אל ${pro.displayName}'),
          onPressed: () {
            // The same rule the listing's chat button follows: a guest is
            // invited to sign in rather than dropped into a wall.
            final isGuest = ref.read(authStateProvider).valueOrNull == null;
            if (isGuest) {
              showLoginRequired(context, action: 'לפנות לבעל מקצוע');
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('הפנייה תיפתח כאן כשהפיצ\'ר יופעל')),
            );
          },
        ),
      ],
    );
  }
}
