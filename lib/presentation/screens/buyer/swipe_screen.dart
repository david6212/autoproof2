import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/car_model.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/swipe_provider.dart';
import '../../widgets/login_required_sheet.dart';
import '../../widgets/verified_badge_widget.dart';

class SwipeScreen extends ConsumerWidget {
  const SwipeScreen({super.key});

  Future<void> _like(BuildContext context, WidgetRef ref, CarModel car) async {
    // Liking creates a match/chat, which requires an account.
    final isGuest = ref.read(authStateProvider).valueOrNull == null;
    if (isGuest) {
      ref.read(analyticsHelperProvider).guestPrompt('like');
      showLoginRequired(context, action: 'לסמן שאהבת ולהתאים');
      return;
    }
    final isMatch = await ref.read(likeCarProvider).call(car);
    if (isMatch && context.mounted) {
      context.push('/match');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = ref.watch(swipeCandidatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('גלה רכבים'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => context.push('/chats'),
          ),
        ],
      ),
      body: SafeArea(
        child: candidates.isEmpty
            ? const _NoMoreCards()
            : _SwipeBody(
                car: candidates.first,
                remaining: candidates.length,
                onSkip: () => ref.read(skipCarProvider).call(candidates.first),
                onLike: () => _like(context, ref, candidates.first),
                onInfo: () => context.push('/car/${candidates.first.id}'),
              ),
      ),
    );
  }
}

class _SwipeBody extends StatelessWidget {
  const _SwipeBody({
    required this.car,
    required this.remaining,
    required this.onSkip,
    required this.onLike,
    required this.onInfo,
  });

  final CarModel car;
  final int remaining;
  final VoidCallback onSkip;
  final VoidCallback onLike;
  final VoidCallback onInfo;

  static final _fmt = NumberFormat('#,###', 'en');

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  car.coverPhoto == null
                      ? Container(
                          color: AppColors.tealLight,
                          child: const Icon(Icons.directions_car,
                              size: 80, color: AppColors.teal),
                        )
                      : CachedNetworkImage(
                          imageUrl: car.coverPhoto!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.tealLight,
                            child: const Icon(Icons.directions_car,
                                size: 80, color: AppColors.teal),
                          ),
                        ),
                  const Positioned(top: 12, right: 12, child: VerifiedBadge()),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            AppColors.tealDark.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  car.title,
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                '₪${_fmt.format(car.price)}',
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_fmt.format(car.km)} ק"מ · יד ${car.hand} · ${car.area} · ${car.year}',
                            style: const TextStyle(
                                color: AppColors.tealLight, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CircleButton(
                icon: Icons.close,
                color: AppColors.errorRed,
                size: 64,
                onTap: onSkip,
              ),
              const SizedBox(width: 20),
              _CircleButton(
                icon: Icons.info_outline,
                color: AppColors.textMuted,
                size: 52,
                onTap: onInfo,
              ),
              const SizedBox(width: 20),
              _CircleButton(
                icon: Icons.favorite,
                color: AppColors.teal,
                size: 64,
                onTap: onLike,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(icon, color: color, size: size * 0.42),
      ),
    );
  }
}

class _NoMoreCards extends StatelessWidget {
  const _NoMoreCards();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.done_all, size: 64, color: AppColors.teal),
          const SizedBox(height: 12),
          const Text('עברת על כל הרכבים הזמינים',
              style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
            onPressed: () => context.go('/discover'),
            child: const Text('שנה העדפות'),
          ),
        ],
      ),
    );
  }
}
