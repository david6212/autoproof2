import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../providers/swipe_provider.dart';

class MatchScreen extends ConsumerWidget {
  const MatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final match = ref.watch(lastMatchProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.tealDark, AppColors.teal],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'שני הצדדים מתעניינים',
                  style: TextStyle(color: AppColors.tealLight, fontSize: 15),
                ),
                const SizedBox(height: 8),
                const Text(
                  'יש התאמה!',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),
                _Avatars(photo: match?.car.coverPhoto),
                const SizedBox(height: 32),
                if (match != null) _CarCard(title: match.car.title),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.white,
                      foregroundColor: AppColors.teal,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: () {
                      if (match != null) {
                        context.push('/chat/${match.chatId}');
                      } else {
                        context.go('/chats');
                      }
                    },
                    child: const Text('שלח הודעה ראשונה',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.white,
                      side: const BorderSide(color: AppColors.white),
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: () => context.go('/swipe'),
                    child: const Text('המשך לגלות'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatars extends StatelessWidget {
  const _Avatars({required this.photo});
  final String? photo;

  @override
  Widget build(BuildContext context) {
    // Fixed width so the Stack doesn't collapse to the heart's size — that
    // was pushing the two 90px avatars off-screen.
    return SizedBox(
      width: 220,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Buyer avatar (right).
          Positioned(
            right: 0,
            child: _circle(const Icon(Icons.person,
                size: 40, color: AppColors.teal)),
          ),
          // Car avatar (left) — the listing's cover photo.
          Positioned(
            left: 0,
            child: _circle(
              photo == null || photo!.isEmpty
                  ? const Icon(Icons.directions_car,
                      size: 40, color: AppColors.teal)
                  : ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: photo!,
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Icon(
                            Icons.directions_car,
                            size: 40,
                            color: AppColors.teal),
                      ),
                    ),
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite, color: AppColors.errorRed),
          ),
        ],
      ),
    );
  }

  Widget _circle(Widget child) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: AppColors.tealLight,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 3),
      ),
      child: Center(child: child),
    );
  }
}

class _CarCard extends StatelessWidget {
  const _CarCard({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user, color: AppColors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Text('בעלים פרטי מאומת',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
