import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../widgets/autoproof_logo.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _layers = [
    (Icons.verified_user, 'אימות מוכר חובה',
        'כל מוכר מוצלב מול מרשם הרכב הממשלתי. רק בעלים פרטיים — אף סוחר.'),
    (Icons.assignment_outlined, 'נתונים רשמיים',
        'ק"מ, טסט, בעלות ותוקף רישיון — ישירות ממשרד התחבורה, בחינם.'),
    (Icons.build_outlined, 'בדיקה עצמאית',
        'בודקי רכב מוסמכים ובלתי תלויים, עם תשלום רק אחרי הבדיקה.'),
    (Icons.chat_bubble_outline, 'צ\'אט מאובטח',
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
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final l in _layers)
                    _LayerCard(icon: l.$1, title: l.$2, body: l.$3),
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
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.arrow_forward,
                  color: AppColors.textPrimary),
              onPressed: () => context.pop(),
            ),
          ),
          // Splash-style brand mark (shield + car + check).
          const AutoproofLogo(size: 96),
          const SizedBox(height: 10),
          const Text(
            AppStrings.appName,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: AppColors.tealText,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            AppStrings.tagline,
            style: TextStyle(color: AppColors.teal, fontSize: 15),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.tealLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(body,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
