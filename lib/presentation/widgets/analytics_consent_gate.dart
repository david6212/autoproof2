import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import '../providers/analytics_consent_provider.dart';
import 'app_card.dart';

/// Asks about measurement once, before any of it happens.
///
/// Analytics used to start on the splash screen: a `_ga` identifier written
/// and two `collect` calls sent before the reader had seen a word, let alone
/// agreed to anything. Under ePrivacy Art. 5(3) storing that identifier needs
/// prior consent, and GDPR Art. 4(11) wants "a clear affirmative action" —
/// neither of which a notice further into the app can provide after the fact.
///
/// Wrapped around the whole navigator, so it does not matter which screen the
/// visitor lands on from a shared link.
class AnalyticsConsentGate extends ConsumerStatefulWidget {
  const AnalyticsConsentGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AnalyticsConsentGate> createState() =>
      _AnalyticsConsentGateState();
}

class _AnalyticsConsentGateState extends ConsumerState<AnalyticsConsentGate> {
  bool _asked = false;

  @override
  Widget build(BuildContext context) {
    final consent = ref.watch(analyticsConsentProvider).valueOrNull;

    if (!_asked && consent == AnalyticsConsent.unasked) {
      _asked = true;
      // After the frame: a route cannot be pushed while one is building, and
      // the splash animation should not be interrupted mid-entrance.
      WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
    }

    return widget.child;
  }

  Future<void> _ask() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // No barrier dismiss and no X. Not to trap anybody — both answers are
      // one tap away and equally easy — but because dismissing a consent
      // question is not an answer, and we would only ask again.
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) => const _ConsentSheet(),
    );
  }
}

class _ConsentSheet extends ConsumerWidget {
  const _ConsentSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> answer(AnalyticsConsent value) async {
      await ref.read(analyticsConsentProvider.notifier).set(value);
      if (context.mounted) Navigator.of(context).pop();
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('מדידת שימוש', style: AppText.h3),
            const SizedBox(height: AppSpace.sm),
            const Text(
              'אנחנו רוצים לדעת אילו מסכים נפתחים וכמה חיפושים רצים, כדי לדעת '
              'מה לשפר. זהו מזהה מתמשך שנשמר במכשיר ונשלח ל-Firebase Analytics '
              'של Google.',
              style: AppText.bodySm,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              'מספר הרישוי אף פעם לא נשלח. אפשר לשנות את התשובה בכל רגע '
              'בפרופיל, והאפליקציה עובדת אותו דבר בשתי האפשרויות.',
              style: context.text.bodySmMuted,
            ),
            const SizedBox(height: AppSpace.lg),
            // Two buttons of the same size, in the same row, in the same
            // visual weight class. `ethics_test` forbids a decline that is
            // made harder to press than an accept, and a consent dialog is
            // where that rule earns its keep.
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => answer(AnalyticsConsent.declined),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('בלי מדידה'),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => answer(AnalyticsConsent.granted),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('אפשר למדוד'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Align(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/legal/cookies');
                },
                child: const Text('מדיניות העוגיות'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The same choice, permanently reachable — Apple requires that withdrawing
/// consent be as easy to find as giving it was.
class AnalyticsConsentTile extends ConsumerWidget {
  const AnalyticsConsentTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consent = ref.watch(analyticsConsentProvider).valueOrNull;
    final on = consent == AnalyticsConsent.granted;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpace.md),
      child: Row(
        children: [
          Icon(Icons.query_stats_outlined, color: context.colors.textMuted),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('מדידת שימוש', style: AppText.subtitle),
                const SizedBox(height: AppSpace.xxs),
                Text(
                  on
                      ? 'מופעלת. מספר הרישוי אף פעם לא נשלח.'
                      : 'כבויה. לא נשלחת שום מדידה.',
                  style: context.text.caption,
                ),
              ],
            ),
          ),
          Switch(
            value: on,
            onChanged: (v) => ref.read(analyticsConsentProvider.notifier).set(
                  v ? AnalyticsConsent.granted : AnalyticsConsent.declined,
                ),
          ),
        ],
      ),
    );
  }
}
