import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/constants/app_strings.dart';
import '../../../app/router.dart';
import '../../widgets/otov_logo.dart';
import '../../../core/theme/app_text.dart';
import '../../widgets/app_card.dart';
import '../../../core/theme/app_dimens.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // Each line must describe what the app actually does — no service we don't
  // provide, no check we don't run. See BUSINESS_ROADMAP section 10.
  static const _layers = [
    (Icons.verified_user, 'נתונים ממרשם הרכב',
        'מספר הרישוי של כל מודעה מושווה למידע הזמין במרשם הרכב הממשלתי, והמוכר מסומן לפי הסיווג שבחר — בעלים פרטי, סוכן או סוחר. איננו מאמתים זהות או בעלות.'),
    (Icons.assignment_outlined, 'נתונים רשמיים',
        'ק"מ, טסט, בעלות ותוקף רישיון — ישירות ממשרד התחבורה, בחינם.'),
    (Icons.build_outlined, 'מכוני בדיקה מורשים',
        'רשימת מכוני הבדיקה המורשים של משרד התחבורה, עם מפה וניווט. הבדיקה וההתקשרות נעשות ישירות מולם.'),
    (Icons.chat_bubble_outline, 'צ\'אט פרטי',
        'התקשרות ישירה עם המוכר בתוך האפליקציה, בלי מתווכים.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    '4 שכבות אמון',
                    style: AppText.h3,
                  ),
                  const SizedBox(height: 12),
                  for (final l in _layers)
                    _LayerCard(icon: l.$1, title: l.$2, body: l.$3),
                  const SizedBox(height: AppSpace.sm),
                  Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.gavel_outlined, size: 18),
                      label: const Text('תנאי שימוש, פרטיות ונהלים'),
                      onPressed: () => context.push('/legal'),
                    ),
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

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(bottom: BorderSide(color: context.colors.cardBorder)),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: Icon(Icons.arrow_forward,
                  color: context.colors.textPrimary),
              onPressed: () => popOrHome(context),
            ),
          ),
          // Splash-style brand mark (shield + car + check).
          const OtovLogo(size: 120, withWordmark: true),
          const SizedBox(height: 8),
          Text(
            AppStrings.tagline,
            style: TextStyle(color: context.colors.teal, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _LayerCard extends StatelessWidget {
  const _LayerCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.colors.tealLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: context.colors.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppText.subtitle),
                const SizedBox(height: 4),
                Text(body,
                    style: TextStyle(
                        color: context.colors.textMuted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
