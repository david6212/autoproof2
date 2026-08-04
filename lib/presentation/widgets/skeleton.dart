import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import 'car_card_widget.dart';
import 'responsive_frame.dart';

/// A placeholder block that shimmers while real content loads.
///
/// A centred spinner tells someone the app is busy; a skeleton tells them
/// what is about to arrive, and the page doesn't jump when it does.
///
/// The shimmer is a white band swept across a grey base, which brightens
/// correctly on both the light and the dark palette — lerping toward the
/// surface colour would darken it in dark mode.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = AppRadius.xs,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.colors.cardBorder;
    final highlight =
        Color.alphaBlend(Colors.white.withValues(alpha: 0.35), base);

    // Respect the platform's "reduce motion" setting: a sweeping band is
    // exactly the kind of thing that setting exists to switch off.
    if (MediaQuery.disableAnimationsOf(context)) {
      return _box(base, null);
    }

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value * 2 - 1; // -1 → 1
        return _box(
          base,
          LinearGradient(
            begin: Alignment(t - 1, 0),
            end: Alignment(t + 1, 0),
            colors: [base, highlight, base],
            stops: const [0.35, 0.5, 0.65],
          ),
        );
      },
    );
  }

  Widget _box(Color base, Gradient? gradient) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: gradient == null ? base : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      );
}

/// A car card's silhouette: the photo strip, a title line and a detail line.
/// Sized from [CarCard] itself so the two can't drift apart.
class CarCardSkeleton extends StatelessWidget {
  const CarCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.colors.cardBorder),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(
            height: CarCard.photoHeight,
            radius: 0,
            width: double.infinity,
          ),
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Skeleton(height: 16)),
                    SizedBox(width: 40),
                    Skeleton(height: 16, width: 64),
                  ],
                ),
                SizedBox(height: 8),
                Skeleton(height: 12, width: 180),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Stand-in for the listings, laid out exactly as [CarListView] will lay out
/// the real ones — same breakpoint, same spacing — so nothing shifts.
class CarListSkeleton extends StatelessWidget {
  const CarListSkeleton({
    super.key,
    this.count = 4,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 16),
  });

  final int count;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isGrid = constraints.maxWidth > AppBreakpoint.carGrid;
        final cards = List.generate(count, (_) => const CarCardSkeleton());

        return IgnorePointer(
          child: Padding(
            padding: padding,
            child: isGrid
                ? GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio:
                        (constraints.maxWidth / 2) / CarCard.heightFor(context),
                    physics: const NeverScrollableScrollPhysics(),
                    children: cards,
                  )
                : ListView.separated(
                    itemCount: count,
                    physics: const NeverScrollableScrollPhysics(),
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (_, i) => cards[i],
                  ),
          ),
        );
      },
    );
  }
}

/// Stand-in for a row in the chat list.
class ChatListSkeleton extends StatelessWidget {
  const ChatListSkeleton({super.key, this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ListView.separated(
        itemCount: count,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, __) => const ListTile(
          leading: Skeleton(width: 52, height: 52, radius: AppRadius.pill),
          title: Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Skeleton(height: 14, width: 120),
          ),
          subtitle: Skeleton(height: 12, width: 200),
          trailing: Skeleton(height: 12, width: 34),
        ),
      ),
    );
  }
}
