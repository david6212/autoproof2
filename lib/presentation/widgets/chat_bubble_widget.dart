import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// A single chat message bubble. Buyer/own messages are teal on the right;
/// the other party's are grey on the left.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.text,
    required this.isMine,
    required this.time,
  });

  final String text;
  final bool isMine;
  final String time;

  @override
  Widget build(BuildContext context) {
    final bg = isMine ? AppColors.teal : AppColors.white;
    final fg = isMine ? AppColors.white : AppColors.textPrimary;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          border: isMine
              ? null
              : Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: TextStyle(color: fg, fontSize: 15)),
            const SizedBox(height: 2),
            Text(
              time,
              style: TextStyle(
                color: isMine
                    ? AppColors.tealLight
                    : AppColors.textSubtle,
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
