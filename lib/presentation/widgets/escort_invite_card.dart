import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_config.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import 'app_card.dart';

/// The offer to bring somebody who knows engines to the viewing.
///
/// **On every listing, not only the ones with a finding.** A card that appeared
/// beside a warning would be a second warning — the app would be saying, about
/// one identified car, that this is the kind you bring a mechanic to. The
/// decision it supports belongs to every viewing, so it is offered at every
/// viewing.
///
/// It draws nothing while the feature is off ([AppConfig.escortEnabled]).
class EscortInviteCard extends StatelessWidget {
  const EscortInviteCard({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.escortEnabled) return const SizedBox.shrink();

    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      child: AppCard(
        onTap: () => context.push('/escort'),
        child: Row(
          children: [
            Icon(Icons.handshake_outlined, size: 22, color: colors.teal),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('לא בטוחים? קחו מישהו שמבין',
                      style: AppText.subtitle),
                  const SizedBox(height: 2),
                  Text(
                    'בעלי מקצוע שמלווים לבדיקת רכב, במחיר שהם קובעים. '
                    'ליד כל אחד כתוב מה נבדק לגביו.',
                    style: context.text.micro,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_left, size: 20, color: colors.textSubtle),
          ],
        ),
      ),
    );
  }
}
