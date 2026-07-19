import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

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
              body: 'בעלים פרטי מאומת השיב להודעתך',
              unread: true,
            ),
            _NotificationTile(
              icon: Icons.verified_user_outlined,
              title: 'ברוך הבא ל-AutoProof',
              body: 'רק מוכרים פרטיים מאומתים. הכוח בידיים שלך.',
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: unread ? AppColors.tealLight : AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
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
