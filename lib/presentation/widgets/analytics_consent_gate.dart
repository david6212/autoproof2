import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart' show rootNavigatorKey;
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
  /// Whether an attempt is in flight, so two frames cannot open two sheets.
  bool _asking = false;

  /// Attempts made. Bounded, so a router that never settles cannot turn this
  /// into a loop that reopens a sheet forever.
  int _attempts = 0;

  @override
  Widget build(BuildContext context) {
    final consent = ref.watch(analyticsConsentProvider).valueOrNull;

    if (!_asking && consent == AnalyticsConsent.unasked) {
      // After the frame: a route cannot be pushed while one is building, and
      // the splash animation should not be interrupted mid-entrance.
      WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
    }

    return widget.child;
  }

  Future<void> _ask() async {
    if (!mounted || _asking) return;
    _asking = true;
    _attempts++;

    // Let the app settle first. A modal is a route, and go_router rebuilds
    // the whole stack when it navigates — splash → onboarding → home wipes an
    // imperatively pushed sheet out from under itself. Measured on the live
    // site: the sheet opened and vanished, so nobody was ever asked.
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) {
      _asking = false;
      return;
    }
    // The navigator's own context, not this widget's: this gate wraps the
    // navigator, so its context has no Navigator ancestor and the sheet had
    // nowhere to open. It failed silently on the live site — the sheet simply
    // never appeared — which is why this is verified in a browser and not
    // assumed from the code reading correctly.
    final navContext = rootNavigatorKey.currentContext;
    // Read after the delay, so it is current — and checked for mount, which
    // is also what tells the analyzer this is not a stale context.
    if (navContext == null || !navContext.mounted) {
      _asking = false;
      return;
    }

    await showModalBottomSheet<void>(
      context: navContext,
      isScrollControlled: true,
      // No barrier dismiss and no X. Not to trap anybody — both answers are
      // one tap away and equally easy — but because dismissing a consent
      // question is not an answer, and we would only ask again.
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) => const _ConsentSheet(),
    );

    _asking = false;

    // If the sheet went away without an answer — which is what a navigation
    // does to it — ask again once things are quiet. Bounded, and it stops the
    // moment there IS an answer.
    if (mounted &&
        _attempts < 5 &&
        ref.read(analyticsConsentProvider).valueOrNull ==
            AnalyticsConsent.unasked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
    }
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
            // The wording, rewritten 25/08. It said the true thing in the
            // voice of a legal notice — "זהו מזהה מתמשך שנשמר במכשיר
            // ונשלח ל-Firebase Analytics" — as the second sentence a newcomer
            // reads. The facts are unchanged and none was dropped; what moved
            // is which of them opens.
            //
            // What could NOT change, whatever it costs in warmth: two buttons
            // of equal weight, an active choice, and no "carrying on means you
            // agreed". Implied consent is not consent (CJEU, Planet49), a
            // single-button banner is what CNIL fined Google €150M for, and
            // Apple rejects under §5.1.1(ii). A friendlier sheet that cannot
            // ship is not friendlier.
            const Text('עוזרים לנו לשפר?', style: AppText.h3),
            const SizedBox(height: AppSpace.sm),
            const Text(
              'אם תרשו, נדע אילו מסכים נפתחים וכמה חיפושים רצים — ולפי זה '
              'נחליט מה לשפר. מספר הרישוי לעולם לא נשלח.',
              style: AppText.bodySm,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              'האפליקציה עובדת בדיוק אותו דבר בשתי האפשרויות, ואפשר '
              'לשנות את התשובה בכל רגע בפרופיל.',
              style: context.text.bodySmMuted,
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              'בפועל: מזהה מתמשך שנשמר במכשיר ונשלח ל-Firebase Analytics של Google.',
              style: context.text.micro,
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
                    child: const Text('לא, תודה'),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => answer(AnalyticsConsent.granted),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('כן, בשמחה'),
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
