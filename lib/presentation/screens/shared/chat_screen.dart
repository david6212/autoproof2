import 'package:flutter/material.dart';

import '../../widgets/placeholder_scaffold.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key, required this.chatId});

  final String chatId;

  @override
  Widget build(BuildContext context) =>
      PlaceholderScaffold(title: 'צ\'אט', subtitle: 'chatId: $chatId');
}
