import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../data/models/chat_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/guest_prompt_view.dart';

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
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Text('שגיאה בטעינת הצ\'אטים',
                style: TextStyle(color: context.colors.textMuted)),
          ),
          data: (chats) {
            if (chats.isEmpty) return const _EmptyChats();
            return ListView.separated(
              itemCount: chats.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) =>
                  _ChatTile(chat: chats[i], me: me),
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

    return ListTile(
      onTap: () => context.push('/chat/${chat.id}'),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: context.colors.tealLight,
        backgroundImage: chat.carPhoto.isNotEmpty
            ? CachedNetworkImageProvider(chat.carPhoto)
            : null,
        child: chat.carPhoto.isEmpty
            ? Icon(Icons.directions_car, color: context.colors.teal)
            : null,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 4),
          Icon(Icons.verified, size: 14, color: context.colors.teal),
        ],
      ),
      subtitle: Text(
        chat.lastMessage.isEmpty ? chat.carTitle : chat.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: unread ? context.colors.textPrimary : context.colors.textMuted,
          fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _time(chat.lastMessageAt),
            style: TextStyle(color: context.colors.textSubtle, fontSize: 12.5),
          ),
          if (unread) ...[
            const SizedBox(height: 4),
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                  color: context.colors.teal, shape: BoxShape.circle),
            ),
          ],
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
