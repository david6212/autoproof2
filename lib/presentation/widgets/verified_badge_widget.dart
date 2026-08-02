import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/constants/app_strings.dart';

/// Pill badge naming the check that ran, not the person: it says
/// "נתונים ממרשם הרכב" — it names where the data came from, never an act
/// of verification we performed. See AppStrings.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: context.colors.tealLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: compact ? 13 : 15, color: context.colors.teal),
          const SizedBox(width: 4),
          Text(
            AppStrings.verifiedSellerBadge,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.bold,
              color: context.colors.tealText2,
            ),
          ),
        ],
      ),
    );
  }
}
