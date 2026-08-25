import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/place.dart';
import '../../../data/models/service_record.dart';
import '../../providers/place_provider.dart';
import 'star_rating.dart';

/// The garages this car has actually been to.
///
/// Built from the vehicle's own service records — only the ones where the
/// owner picked a garage from the directory rather than typing a name. Most
/// records will not qualify, and the section simply is not there then.
///
/// **The rating is read live rather than stored on the record.** A rating
/// copied onto a service log at save time would show that garage's standing on
/// the day of the service, forever. This reads the handful of places the car
/// has been to, once per screen.
class MyGaragesSection extends ConsumerWidget {
  const MyGaragesSection({
    super.key,
    required this.vehicleId,
    required this.services,
  });

  final String vehicleId;
  final List<ServiceRecord> services;

  List<String> get _usedPlaceIds => services
      .map((s) => s.placeId)
      .whereType<String>()
      .toSet()
      .toList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = _usedPlaceIds;
    if (ids.isEmpty) return const SizedBox.shrink();

    final placesAsync = ref.watch(placesByIdsProvider(ids));
    final places = placesAsync.valueOrNull ?? const <Place>[];
    // Silent while loading and silent on failure: this is a convenience
    // shortcut to pages reachable from the timeline anyway, and a spinner or
    // an error box for it would be louder than the thing itself.
    if (places.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('מוסכים שהייתם בהם', style: AppText.subtitle),
        const SizedBox(height: AppSpace.sm),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: places.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpace.sm),
            itemBuilder: (context, i) => _PlaceCard(
              place: places[i],
              visits: services
                  .where((s) => s.placeId == places[i].id)
                  .length,
              vehicleId: vehicleId,
            ),
          ),
        ),
        const SizedBox(height: AppSpace.lg),
      ],
    );
  }
}

class _PlaceCard extends ConsumerWidget {
  const _PlaceCard({
    required this.place,
    required this.visits,
    required this.vehicleId,
  });

  final Place place;
  final int visits;
  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final reviewed = ref.watch(myPlaceReviewProvider(place.id)).valueOrNull;

    return SizedBox(
      width: 186,
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
              const SizedBox(height: 2),
              Text(
                visits == 1 ? 'ביקור אחד' : '$visits ביקורים',
                style: context.text.micro,
              ),
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
              // Either you have rated it, or here is the way to. The invitation
              // that the save-time prompt deliberately does not repeat lives
              // here instead, permanently and out of the way.
              if (reviewed != null)
                Row(
                  children: [
                    Icon(Icons.check_rounded, size: 14, color: colors.tealText),
                    const SizedBox(width: 4),
                    Text('דירגתם',
                        style: context.text.micro
                            .copyWith(color: colors.tealText)),
                  ],
                )
              else
                InkWell(
                  onTap: () => context.push(
                      '/place/${place.id}/review?vehicleId=$vehicleId'),
                  child: Row(
                    children: [
                      Text('דרג',
                          style: AppText.bodySm
                              .copyWith(color: colors.tealText2)),
                      Icon(Icons.chevron_left,
                          size: 15, color: colors.tealText2),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
