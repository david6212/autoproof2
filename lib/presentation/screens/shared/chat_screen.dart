import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/chat_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/chat_bubble_widget.dart';
import '../../widgets/error_retry.dart';

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
    final chat = chatAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
          // Deliberately no retry: this is only the app-bar title, and the
          // message list below carries the real failure and the real button.
          // Two retries for one failed load would be one too many.
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
                error: (_, __) => ErrorRetry(
                  message: 'לא הצלחנו לטעון את ההודעות',
                  onRetry: () =>
                      ref.invalidate(messagesProvider(widget.chatId)),
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
                      final mine = m.senderId == me;
                      return ChatBubble(
                        text: m.text,
                        isMine: mine,
                        time: _time(m.createdAt),
                        // Computed from the chat's own lastRead/deliveredAt
                        // stamps rather than stored per message: the same two
                        // fields already answer it for every message at once,
                        // so a conversation costs no extra reads and no extra
                        // writes to show its ticks.
                        status: mine && chat != null
                            ? chat.statusOf(
                                m.createdAt,
                                chat.otherParticipant(me),
                              )
                            : null,
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
            Icon(Icons.verified, size: 15, color: context.colors.onBrand),
          ],
        ),
        if (chat != null && chat!.carTitle.isNotEmpty)
          Text(
            chat!.carTitle,
            style: TextStyle(fontSize: 12.5, color: context.colors.tealLight),
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
      color: context.colors.tealLight,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Text(
        AppStrings.chatWithVerified,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.colors.tealText2, fontSize: 12.5),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 56, color: context.colors.textSubtle),
          const SizedBox(height: 12),
          Text('שלח הודעה ראשונה למוכר',
              style: TextStyle(color: context.colors.textMuted)),
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
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.cardBorder)),
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
                fillColor: context.colors.background,
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
            backgroundColor: context.colors.tealFill,
            child: IconButton(
              icon: Icon(Icons.send, color: context.colors.onBrand),
              onPressed: onSend,
            ),
          ),
        ],
      ),
    );
  }
}
