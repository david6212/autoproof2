import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../data/models/car_model.dart';

/// Colored pill showing WHO is selling: בעלים פרטי (green) / סוכן (blue) /
/// סוחר (orange). Every listing is labeled so buyers know who they deal with.
class SellerTypeBadge extends StatelessWidget {
  const SellerTypeBadge({super.key, required this.type, this.compact = false});

  final SellerType type;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (type) {
      SellerType.private => (context.colors.tealLight, context.colors.tealText2, Icons.verified_user),
      SellerType.agent => (context.colors.agentBlueBg, context.colors.agentBlue, Icons.handshake_outlined),
      SellerType.dealer => (context.colors.dealerOrangeBg, context.colors.dealerOrange, Icons.storefront_outlined),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 13 : 15, color: fg),
          const SizedBox(width: 4),
          Text(
            type.label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
