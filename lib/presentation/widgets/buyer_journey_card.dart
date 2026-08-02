import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_palette.dart';
import '../providers/auth_provider.dart';
import '../providers/cars_provider.dart';
import '../../core/theme/app_text.dart';
import 'app_card.dart';
import 'login_required_sheet.dart';

/// External deep-check report the buyer can order from a partner service.
/// Keep the URLs here (clean, no tracking params) so they're easy to swap for
/// affiliate links once partnership deals are signed.
class _ReportLink {
  const _ReportLink({required this.label, required this.url});
  final String label;
  final String url;
}

const _balcarReport =
    _ReportLink(label: 'דוח בלקר', url: 'https://balcar.co.il');

/// A single step in the buyer's guided journey.
class _JourneyStep {
  const _JourneyStep({
    required this.title,
    required this.subtitle,
    this.reports = const [],
    this.automation,
    this.findInspection = false,
  });

  final String title;
  final String subtitle;

  /// Tappable partner reports surfaced at this step (opens externally).
  final List<_ReportLink> reports;

  /// Optional automation note shown when an automated action fires at this step.
  final String? automation;

  /// When true, shows an in-app link to the licensed inspection-center directory.
  final bool findInspection;
}

/// "מסע הקנייה" — a vertical stepper the buyer sees on the car page.
///
/// [currentStage] drives which step is active/done/upcoming. Steps before it
/// render as completed, the one at it as active, later ones as locked. The
/// stage value is still passed in from the screen; per-buyer progress tracking
/// comes in a later step.
class BuyerJourneyCard extends ConsumerWidget {
  const BuyerJourneyCard({super.key, required this.carId});

  final String carId;

  static const _steps = <_JourneyStep>[
    _JourneyStep(
      title: 'בדיקת נתוני רישוי',
      subtitle: '5 מאגרי משרד התחבורה',
    ),
    _JourneyStep(
      title: 'בדיקה פיזית',
      subtitle: 'צפייה ברכב או במוסך',
      findInspection: true,
    ),
    _JourneyStep(
      title: 'בדיקת עומק לפני החלטה',
      subtitle: 'הרכב תקין — הזמינו דוח עומק',
      reports: [_balcarReport],
    ),
    _JourneyStep(
      title: 'סגירת הקנייה',
      subtitle: 'קניתם את הרכב 🎉',
      automation: 'הודעת סגירת ביטוח דרך השותף שלנו',
    ),
  ];

  /// Label for the button that advances FROM each step.
  static const _actionLabels = <String>[
    'התחל בבדיקה',
    'סימנתי — בדקתי את הרכב',
    'הרכב תקין — התקדם',
    'קניתי את הרכב 🎉',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStage = ref.watch(journeyStageProvider(carId)).valueOrNull ?? 1;
    final completed = currentStage >= _steps.length;

    return AppSectionCard(
      icon: Icons.route_outlined,
      title: 'מסע הקנייה',
      trailing: completed
          ? TextButton(
              onPressed: () => ref.read(setJourneyStageProvider).call(carId, 1),
              style: TextButton.styleFrom(
                  foregroundColor: context.colors.textMuted,
                  minimumSize: const Size(0, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 6)),
              child: const Text('אפס', style: TextStyle(fontSize: 12.5)),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _steps.length; i++)
            _StepRow(
              step: _steps[i],
              index: i,
              carId: carId,
              isDone: i < currentStage,
              isActive: i == currentStage,
              isLast: i == _steps.length - 1,
              actionLabel: i == currentStage ? _actionLabels[i] : null,
              onAction:
                  i == currentStage ? () => _advance(context, ref, i) : null,
            ),
          if (completed)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.colors.tealLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.celebration_outlined,
                      size: 17, color: context.colors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('השלמת את מסע הקנייה — בהצלחה עם הרכב החדש!',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: context.colors.tealText)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _advance(BuildContext context, WidgetRef ref, int fromIndex) {
    // Tracking your journey requires an account — prompt guests to sign in.
    final isGuest = ref.read(authStateProvider).valueOrNull == null;
    if (isGuest) {
      showLoginRequired(context, action: 'לעקוב אחר מסע הקנייה');
      return;
    }
    ref.read(setJourneyStageProvider).call(carId, fromIndex + 1);
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.index,
    required this.carId,
    required this.isDone,
    required this.isActive,
    required this.isLast,
    this.actionLabel,
    this.onAction,
  });

  final _JourneyStep step;
  final int index;
  final String carId;
  final bool isDone;
  final bool isActive;
  final bool isLast;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final reached = isDone || isActive;
    final circleColor = reached ? context.colors.teal : context.colors.background;
    final numberColor = reached ? context.colors.onBrand : context.colors.textSubtle;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Marker column: numbered dot + connector line.
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                  border: reached
                      ? null
                      : Border.all(color: context.colors.cardBorder, width: 1.5),
                ),
                child: isDone
                    ? Icon(Icons.check, size: 17, color: context.colors.onBrand)
                    : Center(
                        child: Text('${index + 1}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: numberColor)),
                      ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isDone ? context.colors.teal : context.colors.cardBorder,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Content column.
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color:
                          reached ? context.colors.textPrimary : context.colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(step.subtitle,
                      style: context.text.caption),
                  if (step.findInspection) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.colors.teal,
                        side: BorderSide(color: context.colors.teal),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.build_circle_outlined, size: 17),
                      label: const Text('מצא מכון בדיקה מורשה',
                          style: TextStyle(fontSize: 12.5)),
                      onPressed: () => context.push('/inspectors/$carId'),
                    ),
                  ],
                  for (final report in step.reports) ...[
                    const SizedBox(height: 8),
                    _ReportButton(report: report),
                  ],
                  if (step.automation != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: context.colors.tealLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.bolt,
                              size: 15, color: context.colors.teal),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(step.automation!,
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: context.colors.tealText)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: context.colors.teal,
                          minimumSize: const Size.fromHeight(42),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: onAction,
                        child: Text(actionLabel!,
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable chip that opens a partner report site in the browser.
class _ReportButton extends StatelessWidget {
  const _ReportButton({required this.report});
  final _ReportLink report;

  Future<void> _open(BuildContext context) async {
    final uri = Uri.parse(report.url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('לא ניתן לפתוח את הקישור')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.tealLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.colors.teal.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.description_outlined,
                size: 16, color: context.colors.teal),
            const SizedBox(width: 8),
            Expanded(
              child: Text('הזמנת ${report.label}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.colors.tealText)),
            ),
            Icon(Icons.open_in_new, size: 15, color: context.colors.teal),
          ],
        ),
      ),
    );
  }
}
