import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/chat_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/guest_prompt_view.dart';

/// Unread messages, and nothing else.
///
/// This screen used to list three hardcoded notifications — one of them
/// announced "המוכר השיב להודעתך" to users nobody had written to. Everything
/// here now comes from a real chat document; when there is nothing to report
/// it says so rather than filling the space.
///
/// There is no push notification behind this. `firebase_messaging` is in
/// pubspec.yaml but nothing imports it, so the badge only updates while the
/// app is open. Real push needs a server to send it, i.e. the Blaze plan.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(authStateProvider).valueOrNull == null;
    final unread = ref.watch(unreadChatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('התראות')),
      body: SafeArea(
        child: isGuest
            ? const GuestPromptView(
                icon: Icons.notifications_none,
                title: 'ההתראות שלך',
                body: 'התחבר כדי לקבל עדכון כשמוכר משיב לך.',
              )
            : unread.isEmpty
                ? const _NoNotifications()
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSpace.md),
                    itemCount: unread.length,
                    itemBuilder: (context, i) =>
                        _MessageTile(chat: unread[i]),
                  ),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.chat});

  final ChatModel chat;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpace.sm),
      padding: const EdgeInsets.all(14),
      color: context.colors.tealLight,
      onTap: () => context.push('/chat/${chat.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.chat_bubble_outline, color: context.colors.teal),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        chat.carTitle.isEmpty ? 'הודעה חדשה' : chat.carTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.subtitle,
                      ),
                    ),
                    Text(_ago(chat.lastMessageAt), style: context.text.micro),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  chat.lastMessage,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmMuted,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: context.colors.teal,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  static String _ago(DateTime? at) {
    if (at == null) return '';
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return 'עכשיו';
    if (d.inHours < 1) return 'לפני ${d.inMinutes} דק\'';
    if (d.inDays < 1) return 'לפני ${d.inHours} שעות';
    if (d.inDays < 7) return 'לפני ${d.inDays} ימים';
    return DateFormat('d.M.yy').format(at);
  }
}

class _NoNotifications extends StatelessWidget {
  const _NoNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none,
                size: 64, color: context.colors.textSubtle),
            const SizedBox(height: AppSpace.md),
            Text('אין התראות חדשות', style: context.text.bodyMuted),
            const SizedBox(height: AppSpace.xs),
            Text(
              'כשמוכר ישיב להודעה שלך, היא תופיע כאן.',
              textAlign: TextAlign.center,
              style: context.text.caption,
            ),
          ],
        ),
      ),
    );
  }
}
