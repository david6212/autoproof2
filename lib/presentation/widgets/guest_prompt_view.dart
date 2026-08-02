import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';

/// A full-screen, centered "sign in to continue" prompt shown on tabs that
/// only make sense for a signed-in user (Saved, Chats, Profile) when the
/// visitor is browsing as a guest.
class GuestPromptView extends StatelessWidget {
  const GuestPromptView({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: context.colors.tealLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: context.colors.teal),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.h2,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textMuted),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.teal,
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: () => context.push('/login'),
                child: const Text('התחברות',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
