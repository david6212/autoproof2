import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../data/models/chat_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../widgets/app_card.dart';
import '../../widgets/guest_prompt_view.dart';
import '../../widgets/skeleton.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final isGuest = me.isEmpty;
    final chatsAsync = ref.watch(userChatsProvider);
    // The second tick. Watched but never read: opening this list is the moment
    // a message has demonstrably reached this device, which is the only
    // definition of "delivered" available without push notifications.
    ref.watch(markDeliveredProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('צ\'אטים')),
      body: SafeArea(
        child: isGuest
            ? const GuestPromptView(
                icon: Icons.chat_bubble_outline,
                title: 'שוחח עם המוכרים',
                body: 'התחבר כדי לפתוח שיחות עם בעלי הרכבים.',
              )
            : chatsAsync.when(
          loading: () => const ChatListSkeleton(),
          error: (_, __) => Center(
            child: Text('שגיאה בטעינת הצ\'אטים',
                style: TextStyle(color: context.colors.textMuted)),
          ),
          data: (chats) {
            if (chats.isEmpty) return const _EmptyChats();
            // Cards with their own margin, not divided list tiles — the rest
            // of the app puts content on cards over the page colour, and a
            // full-bleed white list was the last surface that did not.
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xl),
              itemCount: chats.length,
              itemBuilder: (context, i) => _ChatTile(
                chat: chats[i],
                me: me,
                onHide: () => _confirmHide(context, ref, chats[i], me),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Long-press to remove a finished conversation from your own list.
///
/// It asks first, and it says plainly that the other side keeps their copy —
/// people reach for this expecting a delete, and finding out afterwards that
/// the seller can still see everything would be a nasty surprise. It also says
/// a new message brings it back, so nobody uses this expecting to be left
/// alone.
Future<void> _confirmHide(
  BuildContext context,
  WidgetRef ref,
  ChatModel chat,
  String me,
) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpace.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            child: Text(
              'להסיר את השיחה מהרשימה שלכם? היא תישאר אצל הצד השני, ואם '
              'תגיע הודעה חדשה היא תחזור.',
              textAlign: TextAlign.center,
              style: Theme.of(c).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: AppSpace.md),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('הסר מהרשימה'),
            onTap: () => Navigator.of(c).pop(true),
          ),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('ביטול'),
            onTap: () => Navigator.of(c).pop(false),
          ),
        ],
      ),
    ),
  );
  if (ok != true) return;

  await ref.read(hideChatProvider)(chat.id);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: const Text('השיחה הוסרה מהרשימה'),
      action: SnackBarAction(
        label: 'ביטול',
        onPressed: () => ref.read(hideChatProvider)(chat.id, hide: false),
      ),
    ));
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.chat,
    required this.me,
    required this.onHide,
  });
  final ChatModel chat;
  final String me;
  final VoidCallback onHide;

  String _time(DateTime? d) {
    if (d == null) return '';
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final isSeller = me == chat.sellerId;
    final title = isSeller ? 'קונה מתעניין' : 'מוכר';
    final unread = chat.isUnreadFor(me);

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpace.md),
      padding: const EdgeInsets.all(AppSpace.md),
      onTap: () => context.push('/chat/${chat.id}'),
      onLongPress: onHide,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: context.colors.tealLight,
            backgroundImage: chat.carPhoto.isNotEmpty
                ? CachedNetworkImageProvider(chat.carPhoto)
                : null,
            child: chat.carPhoto.isEmpty
                ? Icon(Icons.directions_car, color: context.colors.teal)
                : null,
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The bare `Icons.verified` tick that used to sit here is
                // gone. Unlabelled, next to a person, it says "this seller is
                // verified" — which the app explicitly does not claim: the
                // check compares a PLATE against the registry and never
                // establishes anyone's identity or ownership. The seller-type
                // badge on the listing is where classification belongs, with
                // words attached.
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.subtitle),
                const SizedBox(height: AppSpace.xxs),
                Text(
                  chat.lastMessage.isEmpty ? chat.carTitle : chat.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodySm.copyWith(
                    color: unread
                        ? context.colors.textPrimary
                        : context.colors.textMuted,
                    fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_time(chat.lastMessageAt), style: context.text.micro),
              if (unread) ...[
                const SizedBox(height: AppSpace.xs + 1),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                      color: context.colors.teal, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 64, color: context.colors.textSubtle),
          const SizedBox(height: 12),
          Text('אין עדיין שיחות',
              style: TextStyle(color: context.colors.textMuted)),
        ],
      ),
    );
  }
}
