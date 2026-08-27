import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/place.dart';
import '../../../data/models/place_review.dart';
import '../../../data/models/service_record.dart';
import '../../providers/auth_provider.dart';
import '../../providers/place_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/navigate_sheet.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/garage/star_rating.dart';
import '../../widgets/login_required_sheet.dart';

/// A garage or a car wash: what it is, what people said, and what you did here.
///
/// **Two rules hold this page together.**
///
/// The badge at the top says where the entry came from, always. A place
/// somebody typed in and a place on an official register are not the same
/// claim, and a reader has no way to tell them apart from the name.
///
/// And the average is withheld below three reviews. Two people rendered as
/// "5.0" reads as a verdict on a business that has no idea it is being scored.
class PlaceDetailScreen extends ConsumerWidget {
  const PlaceDetailScreen({super.key, required this.placeId});

  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeAsync = ref.watch(placeByIdProvider(placeId));

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: placeAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ErrorRetry(
            message: 'לא הצלחנו לטעון את המקום',
            onRetry: () => ref.invalidate(placeByIdProvider(placeId)),
          ),
          data: (place) => place == null
              ? const _Missing()
              : _Body(place: place),
        ),
      ),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xxl),
          child: Text(
            'המקום הזה כבר לא ברשימה. ייתכן שהוסר לאחר שכמה אנשים דיווחו '
            'שאינו קיים.',
            textAlign: TextAlign.center,
            style: context.text.bodyMuted,
          ),
        ),
      );
}

class _Body extends ConsumerWidget {
  const _Body({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(placeReviewsProvider(place.id));
    final mine = ref.watch(myPlaceReviewProvider(place.id)).valueOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, 0, AppSpace.lg, AppSpace.xxl),
      children: [
        _Header(place: place),
        const SizedBox(height: AppSpace.lg),
        _Actions(place: place),
        const SizedBox(height: AppSpace.lg),
        _UsedHere(place: place),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: Icon(mine == null ? Icons.star_outline_rounded
                : Icons.edit_outlined, size: 18),
            label: Text(mine == null ? 'כתוב ביקורת' : 'ערוך את הביקורת שלך'),
            onPressed: () {
              if (ref.read(authStateProvider).valueOrNull == null) {
                showLoginRequired(context, action: 'לכתוב ביקורת');
                return;
              }
              context.push('/place/${place.id}/review');
            },
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        reviewsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpace.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => ErrorRetry(
            compact: true,
            message: 'לא הצלחנו לטעון את הביקורות',
            onRetry: () => ref.invalidate(placeReviewsProvider(place.id)),
          ),
          data: (reviews) => _Reviews(
            place: place,
            reviews: reviews,
            myUid: ref.watch(authStateProvider).valueOrNull?.uid,
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        const _Disclaimer(),
        _ReportRow(place: place),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(place.name, style: AppText.h1),
        const SizedBox(height: AppSpace.sm),
        Wrap(
          spacing: AppSpace.xs + 2,
          runSpacing: AppSpace.xs,
          children: [
            // Where the entry came from. Never optional: a community entry and
            // an official one are different claims, and the name alone does
            // not tell them apart.
            _Chip(
              text: place.isCommunity
                  ? 'נוסף על ידי הקהילה'
                  : 'רשום במשרד התחבורה',
              fg: place.isCommunity ? colors.dealerOrange : colors.agentBlue,
              bg: place.isCommunity
                  ? colors.dealerOrangeBg
                  : colors.agentBlueBg,
            ),
            _Chip(
              text: place.category.label,
              fg: colors.tealText,
              bg: colors.tealLight,
            ),
          ],
        ),
        if (place.address.isNotEmpty || place.city.isNotEmpty) ...[
          const SizedBox(height: AppSpace.sm),
          Text(
            [place.address, place.city].where((s) => s.isNotEmpty).join(', '),
            style: context.text.bodyMuted,
          ),
        ],
        const SizedBox(height: AppSpace.md),
        // Below three reviews there is no average, only a count — and an
        // invitation, because the honest thing to say is that nobody has
        // rated this yet.
        if (place.hasEnoughRatings)
          Row(
            children: [
              Text(place.ratingAvg.toStringAsFixed(1), style: AppText.h2),
              const SizedBox(width: AppSpace.sm),
              StarRating(rating: place.ratingAvg, size: 18),
              const SizedBox(width: AppSpace.sm),
              Text('${place.ratingCount} ביקורות',
                  style: context.text.bodyMuted),
            ],
          )
        else
          Text(
            place.ratingCount == 0
                ? 'עדיין אין ביקורות. היה הראשון לדרג.'
                : 'יש ${place.ratingCount} ביקורות. נציג ממוצע מ-'
                    '${Place.minRatingsToShow} ומעלה.',
            style: context.text.bodyMuted,
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.fg, required this.bg});

  final String text;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.bold, color: fg)),
      );
}

class _Actions extends StatelessWidget {
  const _Actions({required this.place});

  final Place place;

  Future<void> _open(Uri uri) async {
    // Silent on failure: there is no useful thing to say when a phone has no
    // dialler or no map, and an error toast about it helps nobody.
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone = (place.phone ?? '').trim().isNotEmpty;

    return Row(
      children: [
        if (hasPhone)
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.call_outlined, size: 18),
              label: const Text('התקשר'),
              onPressed: () => _open(Uri.parse('tel:${place.phone}')),
            ),
          ),
        if (hasPhone) const SizedBox(width: AppSpace.sm),
        // Offered even without coordinates now, which is most community
        // entries: `addCommunityPlace` stores 0,0 because the add screen does
        // not capture a location. NavigateSheet sends the name and the town
        // instead, which is what a person would have typed anyway — and it
        // refuses to hand 0,0 to a navigation app, which would confidently
        // drive somebody into the Atlantic.
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.navigation_outlined, size: 18),
            label: const Text('נווט'),
            onPressed: () => NavigateSheet.show(
              context,
              lat: place.lat,
              lng: place.lng,
              query: [place.name, place.address, place.city]
                  .where((p) => p.trim().isNotEmpty)
                  .join(' '),
              label: place.name,
            ),
          ),
        ),
      ],
    );
  }
}

/// "This place does not exist."
///
/// Only offered for community entries — there is nothing useful a reader can
/// tell us about an official register, and a report button on one would invite
/// people to use it as a complaint box about the business.
///
/// **Three reports hide the place, and the third reporter's device is what
/// hides it**, because this plan has no server to do it. The count is shown
/// before the tap and the report cannot be withdrawn, so nobody files one
/// casually.
class _ReportRow extends ConsumerWidget {
  const _ReportRow({required this.place});

  final Place place;

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    if (ref.read(authStateProvider).valueOrNull == null) {
      showLoginRequired(context, action: 'לדווח על מקום');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('המקום הזה לא קיים?'),
        content: const Text(
          'אחרי שלושה דיווחים המקום יפסיק להופיע ברשימות. '
          'אי אפשר לבטל דיווח.',
          style: AppText.body,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('ביטול')),
          TextButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('דווח')),
        ],
      ),
    );
    if (ok != true) return;

    await ref.read(reportPlaceProvider)(place.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('תודה. הדיווח נרשם.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!place.isCommunity) return const SizedBox.shrink();
    final state = ref.watch(placeReportStateProvider(place.id)).valueOrNull;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.sm),
      child: Row(
        children: [
          if (state != null && state.count > 0)
            Expanded(
              child: Text(
                state.count == 1
                    ? 'אדם אחד דיווח שהמקום הזה לא קיים'
                    : '${state.count} אנשים דיווחו שהמקום הזה לא קיים',
                style: context.text.micro,
              ),
            )
          else
            const Spacer(),
          if (state?.mine == true)
            Text('דיווחת', style: context.text.micro)
          else
            TextButton.icon(
              icon: const Icon(Icons.flag_outlined, size: 16),
              label: const Text('המקום לא קיים'),
              style: TextButton.styleFrom(
                  foregroundColor: context.colors.textMuted),
              onPressed: () => _report(context, ref),
            ),
        ],
      ),
    );
  }
}

/// "You have been here three times" — visible to the owner of the passport and
/// to nobody else.
///
/// It is built from the reader's own service records, so it cannot leak: there
/// is no query here that could return somebody else's visits.
class _UsedHere extends ConsumerWidget {
  const _UsedHere({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(myVehiclesProvider).valueOrNull ?? const [];
    if (vehicles.isEmpty) return const SizedBox.shrink();

    final records = <ServiceRecord>[];
    for (final v in vehicles) {
      final services = ref.watch(vehicleServicesProvider(v.id)).valueOrNull;
      if (services == null) continue;
      records.addAll(services.where((s) => s.placeId == place.id));
    }
    if (records.isEmpty) return const SizedBox.shrink();

    records.sort((a, b) => b.date.compareTo(a.date));

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_car_outlined,
                    size: 17, color: context.colors.teal),
                const SizedBox(width: AppSpace.sm),
                Text(
                  records.length == 1
                      ? 'היית כאן פעם אחת'
                      : 'היית כאן ${records.length} פעמים',
                  style: AppText.subtitle,
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              records.map((r) => r.title).take(4).join(' · '),
              style: context.text.bodyMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _Reviews extends StatelessWidget {
  const _Reviews({
    required this.place,
    required this.reviews,
    required this.myUid,
  });

  final Place place;
  final List<PlaceReview> reviews;
  final String? myUid;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return Text('אין עדיין ביקורות על המקום הזה.',
          style: context.text.bodyMuted);
    }

    // The reader's own review first, always. Everything else newest first.
    final mine = reviews.where((r) => r.uid == myUid).toList();
    final others = reviews.where((r) => r.uid != myUid).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in mine) _ReviewTile(review: r, isMine: true),
        for (final r in others) _ReviewTile(review: r, isMine: false),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review, required this.isMine});

  final PlaceReview review;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: AppCard(
        borderColor: isMine ? colors.teal : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isMine ? 'הביקורת שלך' : review.displayName,
                    style: AppText.subtitle,
                  ),
                ),
                Text(DateFormatter.format(review.createdAt),
                    style: context.text.micro),
              ],
            ),
            const SizedBox(height: AppSpace.xs),
            StarRating(rating: review.rating.toDouble()),
            if (review.text.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpace.sm),
              Text(review.text, style: AppText.bodySm),
            ],
            if (review.serviceType.isNotEmpty ||
                review.vehicleModel.isNotEmpty ||
                review.costPaid != null) ...[
              const SizedBox(height: AppSpace.sm),
              Wrap(
                spacing: AppSpace.xs + 2,
                runSpacing: AppSpace.xs,
                children: [
                  for (final tag in [
                    if (review.serviceType.isNotEmpty) review.serviceType,
                    if (review.vehicleModel.isNotEmpty) review.vehicleModel,
                    if (review.costPaid != null) '₪${review.costPaid}',
                  ])
                    _Chip(
                      text: tag,
                      fg: colors.textMuted,
                      bg: colors.background,
                    ),
                ],
              ),
            ],
            if (review.wasEdited) ...[
              const SizedBox(height: AppSpace.xs),
              Text('עודכנה ב-${DateFormatter.format(review.editedAt!)}',
                  style: context.text.micro),
            ],
          ],
        ),
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: context.colors.background,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: context.colors.cardBorder),
        ),
        child: Text(
          'הדירוגים נכתבו על ידי משתמשים ומשקפים את חווייתם האישית. '
          'BonnetCheck אינה בודקת מוסכים ואינה ממליצה עליהם.',
          style: context.text.micro,
        ),
      );
}
