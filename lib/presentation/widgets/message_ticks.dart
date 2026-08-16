import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../data/models/message_model.dart';

/// One tick, two ticks, two green ticks — on your own messages only.
///
/// The other person's messages carry no ticks: you already know you read them,
/// and a tick there would be telling you something you did.
///
/// **The second tick is weaker here than in WhatsApp**, and the app should not
/// pretend otherwise. WhatsApp gets a message onto a closed phone with a push
/// notification and ticks it delivered; we have no push, so the second tick
/// only appears once the other person's app is open. A message resting on one
/// tick means "their device has not picked it up yet" — not that it failed.
class MessageTicks extends StatelessWidget {
  const MessageTicks({super.key, required this.status, this.onLight = false});

  final MessageStatus status;

  /// Ticks sit on the brand-green bubble by default. On a light surface they
  /// need the darker ink instead.
  final bool onLight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Read is the only state that changes colour. Making "delivered" a
    // different colour too would give three colours to tell apart at 13px,
    // and the shape already carries the difference.
    final colour = switch (status) {
      MessageStatus.read => colors.mintAccent,
      _ => onLight ? colors.textSubtle : colors.tealLight,
    };

    return Semantics(
      label: switch (status) {
        MessageStatus.sent => 'נשלח',
        MessageStatus.delivered => 'הגיע',
        MessageStatus.read => 'נקרא',
      },
      excludeSemantics: true,
      child: Icon(
        status == MessageStatus.sent ? Icons.check : Icons.done_all,
        size: 13,
        color: colour,
      ),
    );
  }
}
