import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/chat_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/chat_bubble_widget.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Opening the conversation is what clears its notification. Deferred to
    // after the first frame so the write never happens during a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(markChatReadProvider).call(widget.chatId);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    await ref.read(sendMessageProvider).call(widget.chatId, text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _time(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    // A message that arrives while the thread is on screen has been seen, so
    // clear it too rather than badging a conversation the user is reading.
    ref.listen(messagesProvider(widget.chatId), (_, __) {
      ref.read(markChatReadProvider).call(widget.chatId);
    });

    final chatAsync = ref.watch(chatProvider(widget.chatId));
    final messagesAsync = ref.watch(messagesProvider(widget.chatId));
    final me = ref.watch(authStateProvider).valueOrNull?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: chatAsync.when(
          data: (chat) => _Header(chat: chat, me: me),
          loading: () => const Text(AppStrings.appName),
          error: (_, __) => const Text(AppStrings.appName),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const _InfoBanner(),
            Expanded(
              child: messagesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(
                  child: Text(AppStrings.errorGeneric,
                      style: TextStyle(color: AppColors.textMuted)),
                ),
                data: (messages) {
                  if (messages.isEmpty) return const _EmptyChat();
                  _scrollToBottom();
                  return ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final m = messages[i];
                      return ChatBubble(
                        text: m.text,
                        isMine: m.senderId == me,
                        time: _time(m.createdAt),
                      );
                    },
                  );
                },
              ),
            ),
            _InputBar(controller: _controller, onSend: _send),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.chat, required this.me});
  final ChatModel? chat;
  final String me;

  @override
  Widget build(BuildContext context) {
    final isSeller = chat != null && me == chat!.sellerId;
    final title = isSeller ? 'קונה מתעניין' : 'מוכר';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            const Icon(Icons.verified, size: 15, color: AppColors.white),
          ],
        ),
        if (chat != null && chat!.carTitle.isNotEmpty)
          Text(
            chat!.carTitle,
            style: const TextStyle(fontSize: 12.5, color: AppColors.tealLight),
          ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.tealLight,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: const Text(
        AppStrings.chatWithVerified,
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.tealText2, fontSize: 12.5),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 56, color: AppColors.textSubtle),
          SizedBox(height: 12),
          Text('שלח הודעה ראשונה למוכר',
              style: TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend});
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'הקלד הודעה...',
                filled: true,
                fillColor: AppColors.background,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.teal,
            child: IconButton(
              icon: const Icon(Icons.send, color: AppColors.white),
              onPressed: onSend,
            ),
          ),
        ],
      ),
    );
  }
}
