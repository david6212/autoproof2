import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';

/// What a screen shows when its data would not load.
///
/// **The retry is the point.** Most of these failures are a lost second of
/// signal in a lift or a car park, and they fix themselves — but a screen that
/// only says "we couldn't load this" leaves the reader with nothing to do
/// except back out, and no reason to believe coming back would help. One
/// button turns a dead end into a two-second recovery.
///
/// It says "we" rather than naming a network or a server: the reader does not
/// care which layer failed, and a technical message reads as blame.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({
    super.key,
    required this.message,
    required this.onRetry,
    this.icon = Icons.cloud_off,
    this.compact = false,
  });

  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  /// For a tab inside a screen, where a full-height centred block would push
  /// the tab bar off the top of the reader's attention.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: compact ? 36 : 48, color: context.colors.textSubtle),
        SizedBox(height: compact ? AppSpace.md : AppSpace.lg),
        Text(message, style: AppText.subtitle, textAlign: TextAlign.center),
        SizedBox(height: compact ? AppSpace.md : AppSpace.lg),
        OutlinedButton(onPressed: onRetry, child: const Text('נסו שוב')),
      ],
    );

    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpace.xl : AppSpace.xxl),
        child: body,
      ),
    );
  }
}
