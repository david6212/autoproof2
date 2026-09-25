import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import '../../data/models/escort_pro.dart';

/// What has and has not been checked about a professional, on one chip.
///
/// **Three states, and the weakest one is shown rather than hidden.** A person
/// offering to inspect a stranger's car for money is the last place this app
/// can afford a vague badge: the chip names the check that ran, never the
/// person, and somebody who proved nothing still appears — carrying a chip
/// that says nothing was proved.
///
/// The colours follow the rule the rest of the app already uses: blue is the
/// state's answer, green is ours, grey is a claim with nobody behind it.
class EscortVerificationChip extends StatelessWidget {
  const EscortVerificationChip({
    super.key,
    required this.verification,
    this.detail,
  });

  final EscortVerification verification;

  /// The line under the chip — what exactly was checked. Optional only
  /// because a dense list has room for the chip alone; wherever a decision is
  /// made, pass it.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final (fg, bg, icon) = switch (verification) {
      EscortVerification.registryListed => (
          colors.agentBlue,
          colors.agentBlueBg,
          Icons.verified_outlined,
        ),
      EscortVerification.certificateChecked => (
          colors.tealText2,
          colors.tealLight,
          Icons.badge_outlined,
        ),
      EscortVerification.selfDeclared => (
          colors.textSubtle,
          colors.cardBorder.withValues(alpha: 0.35),
          Icons.person_outline,
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.sm,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: AppSpace.xs),
              Text(
                verification.label,
                style: context.text.micro
                    .copyWith(color: fg, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        if (detail != null && detail!.isNotEmpty) ...[
          const SizedBox(height: AppSpace.xs),
          Text(detail!, style: context.text.micro),
        ],
      ],
    );
  }
}

/// The sentence that sits above the button a buyer presses.
///
/// Not in the page footer: this is the moment the decision is made, and a
/// limitation a reader meets after deciding is a limitation they never met.
class EscortLiabilityNote extends StatelessWidget {
  const EscortLiabilityNote({super.key});

  static const text =
      'התשלום מתבצע ישירות מול בעל המקצוע. BonnetCheck אינה מעסיקה אותו, '
      'לא בחרה אותו ואינה אחראית לחוות דעתו או לתוצאת הבדיקה.';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: colors.warnBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 15, color: colors.warnText),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              text,
              style: context.text.micro.copyWith(color: colors.warnText),
            ),
          ),
        ],
      ),
    );
  }
}
