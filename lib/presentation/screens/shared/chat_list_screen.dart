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
              itemBuilder: (context, i) => _ChatTile(chat: chats[i], me: me),
            );
          },
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, required this.me});
  final ChatModel chat;
  final String me;

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
