import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/chat_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/alert_prefs_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/common/collapsible_section.dart';
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
            : ListView(
                padding: const EdgeInsets.all(AppSpace.md),
                children: [
                  const _AlertSettings(),
                  const SizedBox(height: AppSpace.md),
                  if (!ref.watch(alertEnabledProvider(AlertKind.chatReplies)))
                    const _AlertsOff()
                  else if (unread.isEmpty)
                    const _NoNotifications()
                  else
                    for (final chat in unread) _MessageTile(chat: chat),
                ],
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


/// A switch per alert, and what each one costs to turn off.
///
/// Folded away by default: it is settings on a screen that exists to show
/// news. Open, it is deliberately plain — four rows, no persuasion, and the
/// consequence spelled out under each label. A toggle whose effect is hidden
/// is not a choice, and nudging someone to leave alerts on would be the same
/// manipulation this list was drawn up to avoid.
class _AlertSettings extends ConsumerWidget {
  const _AlertSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(alertPrefsProvider);

    return CollapsibleSection(
      icon: Icons.tune,
      title: 'מה נציג לכם',
      summary: '${on.length} מתוך ${AlertKind.values.length} סוגי התראות פעילים',
      persistKey: 'alert_settings',
      child: Column(
        children: [
          for (final kind in AlertKind.values) ...[
            if (kind != AlertKind.values.first)
              Divider(height: AppSpace.lg, color: context.colors.cardBorder),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(kind.label, style: AppText.bodySm),
                      const SizedBox(height: AppSpace.xxs),
                      Text(kind.cost, style: context.text.micro),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Switch(
                  value: on.contains(kind),
                  onChanged: (v) =>
                      ref.read(alertPrefsProvider.notifier).set(kind, v),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown instead of the feed when the reader has switched replies off.
///
/// Says which switch is doing it, so an empty screen is never a mystery.
class _AlertsOff extends StatelessWidget {
  const _AlertsOff();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.xxl),
      child: Column(
        children: [
          Icon(Icons.notifications_off_outlined,
              size: 44, color: context.colors.textSubtle),
          const SizedBox(height: AppSpace.md),
          const Text('תשובות מהמוכר כבויות', style: AppText.h3),
          const SizedBox(height: AppSpace.sm),
          Text(
            'ההודעות עצמן ממתינות לכם בלשונית הצ׳אטים.',
            textAlign: TextAlign.center,
            style: context.text.bodyMuted,
          ),
        ],
      ),
    );
  }
}
