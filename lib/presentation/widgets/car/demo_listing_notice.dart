import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/car_model.dart';

/// Says that a demonstration listing is a demonstration listing.
///
/// Four of them are live. Their plates are registered to nobody — that is the
/// rule they were rebuilt under, after the audit found the previous four
/// attached to real cars — and the consequence is that they have no registry
/// data of any kind. So a demo is exactly the listing that reads, to a buyer,
/// as a real car whose official sections happen to be empty. The `demo: true`
/// flag has been in Firestore since the day they were rebuilt and nothing in
/// the app rendered it; the empty sections were the only hint, and an absence
/// is not a statement.
///
/// Placed above the findings rather than below the fold, because everything
/// underneath it — the price, the mileage, the service history, the reason for
/// selling — is invented, and a label that arrives after the reader has formed
/// a view of the car has arrived too late to do anything.
///
/// It carries the warn palette but no alarm word. Nothing here is wrong with a
/// car; there is no car.
class DemoListingNotice extends StatelessWidget {
  const DemoListingNotice({super.key, required this.car});

  final CarModel car;

  @override
  Widget build(BuildContext context) {
    if (!car.isDemo) return const SizedBox.shrink();
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: colors.warnBg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.science_outlined, size: 18, color: colors.warnText),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'מודעת הדגמה',
                    style: AppText.subtitle.copyWith(color: colors.warnText),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'הרכב הזה אינו קיים והמודעה אינה למכירה. המחיר, '
                    'הקילומטראז\' וההיסטוריה הומצאו כדי להדגים את האפליקציה. '
                    'מספר הרישוי שלה אינו רשום לאף רכב — ולכן אין כאן נתונים '
                    'ממשרד התחבורה, ולא בגלל תקלה.',
                    style: context.text.micro.copyWith(color: colors.warnText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
