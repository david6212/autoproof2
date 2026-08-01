import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../../core/theme/app_dimens.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('התראות')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: const [
            _NotificationTile(
              icon: Icons.rate_review_outlined,
              title: 'עזרה לקונה אחר',
              body: 'מישהו עומד לראות רכב שבדקת — יש לך כמה מילים בשבילו?',
              unread: true,
            ),
            _NotificationTile(
              icon: Icons.chat_bubble_outline,
              title: 'הודעה חדשה',
              body: 'המוכר השיב להודעתך',
              unread: true,
            ),
            _NotificationTile(
              icon: Icons.verified_user_outlined,
              title: 'ברוך הבא ל-OtoV',
              body: 'מוכרים מסווגים ומוצלבים מול המרשם. הכוח בידיים שלך.',
              unread: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.icon,
    required this.title,
    required this.body,
    required this.unread,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpace.sm),
      padding: const EdgeInsets.all(14),
      color: unread ? AppColors.tealLight : AppColors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight:
                            unread ? FontWeight.bold : FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(body,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13)),
              ],
            ),
          ),
          if (unread)
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(
                color: AppColors.teal,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
