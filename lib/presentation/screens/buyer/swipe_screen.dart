import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_palette.dart';
import '../../../data/models/car_model.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cars_provider.dart';
import '../../providers/swipe_provider.dart';
import '../../widgets/login_required_sheet.dart';
import '../../widgets/verified_badge_widget.dart';
import '../../../core/theme/app_text.dart';
import '../../widgets/app_card.dart';
import '../../../core/theme/app_dimens.dart';

class SwipeScreen extends ConsumerWidget {
  const SwipeScreen({super.key});

  void _skip(WidgetRef ref, CarModel car) {
    ref.read(swipedIdsProvider.notifier).update((s) => {...s, car.id});
  }

  Future<void> _save(BuildContext context, WidgetRef ref, CarModel car) async {
    // Saving a car requires an account.
    final isGuest = ref.read(authStateProvider).valueOrNull == null;
    if (isGuest) {
      ref.read(analyticsHelperProvider).guestPrompt('save');
      showLoginRequired(context, action: 'לשמור רכבים');
      return;
    }
    await ref.read(toggleSavedProvider).call(car.id, true);
    ref.read(swipedIdsProvider.notifier).update((s) => {...s, car.id});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('סימנת וי — הרכב נשמר ✓')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deck = ref.watch(swipeDeckProvider);

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
        child: deck.isEmpty
            ? const _NoMoreCards()
            : _SwipeBody(
                car: deck.first,
                remaining: deck.length,
                onSkip: () => _skip(ref, deck.first),
                onLike: () => _save(context, ref, deck.first),
                onInfo: () => context.push('/car/${deck.first.id}'),
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
            child: AppCard(
              padding: EdgeInsets.zero,
              radius: AppRadius.xl,
              elevated: true,
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  car.coverPhoto == null
                      ? Container(
                          color: context.colors.tealLight,
                          child: Icon(Icons.directions_car,
                              size: 80, color: context.colors.teal),
                        )
                      : CachedNetworkImage(
                          imageUrl: car.coverPhoto!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: context.colors.tealLight,
                            child: Icon(Icons.directions_car,
                                size: 80, color: context.colors.teal),
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
                            context.colors.tealDark.withValues(alpha: 0.85),
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
                                  style: TextStyle(
                                    color: context.colors.onBrand,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                '₪${_fmt.format(car.price)}',
                                style: TextStyle(
                                  color: context.colors.onBrand,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_fmt.format(car.km)} ק"מ · יד ${car.hand} · ${car.area} · ${car.year}',
                            style: TextStyle(
                                color: context.colors.tealLight, fontSize: 13),
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
                color: context.colors.errorRed,
                size: 64,
                onTap: onSkip,
              ),
              const SizedBox(width: 20),
              _CircleButton(
                icon: Icons.info_outline,
                color: context.colors.textMuted,
                size: 52,
                onTap: onInfo,
              ),
              const SizedBox(width: 20),
              _CircleButton(
                icon: Icons.check,
                color: context.colors.teal,
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
          color: context.colors.surface,
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
          Icon(Icons.done_all, size: 64, color: context.colors.teal),
          const SizedBox(height: 12),
          Text('עברת על כל הרכבים המסוננים',
              style: TextStyle(color: context.colors.textMuted)),
          const SizedBox(height: 4),
          Text('שנה את הסינון בעמוד הבית כדי לראות עוד',
              style: context.text.captionSubtle),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.tealFill),
            onPressed: () => context.go('/home'),
            child: const Text('חזרה לפיד'),
          ),
        ],
      ),
    );
  }
}
