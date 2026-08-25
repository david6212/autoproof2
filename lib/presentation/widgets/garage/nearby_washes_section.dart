import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/place.dart';
import '../../providers/place_provider.dart';
import 'star_rating.dart';

/// Car washes people have added.
///
/// **Always shown, even when there is nothing in it** — unlike the garages
/// section, which appears only once a car has been somewhere. An empty washes
/// row is not a failure state here: it is the invitation, and there is no
/// other way for the first one to get in. No public register of car washes
/// exists to seed this from.
///
/// Distance is not shown. The screen has no location permission of its own and
/// asking for one to decorate a row would be a permission taken for a garnish.
/// The washes map is where distance belongs.
class NearbyWashesSection extends ConsumerWidget {
  const NearbyWashesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final washesAsync = ref.watch(washesProvider);
    final washes = washesAsync.valueOrNull ?? const <Place>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('שטיפות', style: AppText.subtitle),
        const SizedBox(height: AppSpace.sm),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: washes.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpace.sm),
            itemBuilder: (context, i) => i == washes.length
                ? const _AddCard()
                : _WashCard(place: washes[i]),
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          'שטיפות נוספו על ידי הקהילה ואינן מאומתות על ידי BonnetCheck.',
          style: context.text.micro,
        ),
        const SizedBox(height: AppSpace.lg),
      ],
    );
  }
}

class _WashCard extends StatelessWidget {
  const _WashCard({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: 172,
      child: InkWell(
        onTap: () => context.push('/place/${place.id}'),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: colors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.subtitle),
              if (place.city.isNotEmpty)
                Text(place.city, style: context.text.micro),
              const SizedBox(height: AppSpace.sm),
              if (place.hasEnoughRatings)
                Row(
                  children: [
                    StarRating(rating: place.ratingAvg, size: 13),
                    const SizedBox(width: 4),
                    Text('${place.ratingCount}', style: context.text.micro),
                  ],
                )
              else
                Text('אין עדיין דירוג', style: context.text.micro),
              const Spacer(),
              Text('נוסף על ידי הקהילה', style: context.text.micro),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddCard extends StatelessWidget {
  const _AddCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: 148,
      child: InkWell(
        onTap: () => context.push('/place/add?category=car_wash'),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: colors.teal, style: BorderStyle.solid),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: colors.teal),
                const SizedBox(height: 4),
                Text('הוסף שטיפה',
                    style: AppText.bodySm.copyWith(color: colors.tealText2)),
                Text('שלא ברשימה', style: context.text.micro),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
