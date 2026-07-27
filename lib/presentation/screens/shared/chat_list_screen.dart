import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
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
          error: (_, __) => const Center(
            child: Text('שגיאה בטעינת הצ\'אטים',
                style: TextStyle(color: AppColors.textMuted)),
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
    final title = isSeller ? 'קונה מתעניין' : 'מוכר מאומת';

    return ListTile(
      onTap: () => context.push('/chat/${chat.id}'),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: AppColors.tealLight,
        backgroundImage: chat.carPhoto.isNotEmpty
            ? CachedNetworkImageProvider(chat.carPhoto)
            : null,
        child: chat.carPhoto.isEmpty
            ? const Icon(Icons.directions_car, color: AppColors.teal)
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
          const Icon(Icons.verified, size: 14, color: AppColors.teal),
        ],
      ),
      subtitle: Text(
        chat.lastMessage.isEmpty ? chat.carTitle : chat.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textMuted),
      ),
      trailing: Text(
        _time(chat.lastMessageAt),
        style: const TextStyle(color: AppColors.textSubtle, fontSize: 12),
      ),
    );
  }
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 64, color: AppColors.textSubtle),
          SizedBox(height: 12),
          Text('אין עדיין שיחות',
              style: TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
