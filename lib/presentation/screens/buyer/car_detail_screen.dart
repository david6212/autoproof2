import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/car_model.dart';
import '../../../app/router.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cars_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/buyer_journey_card.dart';
import '../../widgets/car_notes_section.dart';
import '../../widgets/car_photo_gallery.dart';
import '../../widgets/gov_red_flags_card.dart';
import '../../widgets/login_required_sheet.dart';
import '../../widgets/plate_history_card.dart';
import '../../widgets/report_listing_sheet.dart';
import '../../widgets/seller_encounter_card.dart';
import '../../widgets/seller_type_badge.dart';
import '../../../core/theme/app_text.dart';
import '../../widgets/heart_check_icon.dart';

class CarDetailScreen extends ConsumerWidget {
  const CarDetailScreen({super.key, required this.carId});

  final String carId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carAsync = ref.watch(carByIdProvider(carId));

    return Scaffold(
      body: carAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _error(context),
        data: (car) {
          if (car == null) return _error(context);
          return _Content(car: car);
        },
      ),
    );
  }

  Widget _error(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: context.colors.errorRed),
            const SizedBox(height: 12),
            Text('הרכב לא נמצא',
                style: TextStyle(color: context.colors.textMuted)),
            const SizedBox(height: 12),
            TextButton(
                onPressed: () => popOrHome(context), child: const Text('חזרה')),
          ],
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.car});
  final CarModel car;

  static final _priceFmt = NumberFormat('#,###', 'en');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedIds = ref.watch(savedIdsProvider).valueOrNull ?? const {};
    final isSaved = savedIds.contains(car.id);

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: CarPhotoGallery(car: car)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              car.title,
                              style: AppText.h1,
                            ),
                          ),
                          Text(
                            '₪${_priceFmt.format(car.price)}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: context.colors.teal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _StatsRow(car: car),
                      const SizedBox(height: 14),
                      // Official red flags (accident / recall / off-road),
                      // pulled forward from the full history screen.
                      GovRedFlagsCard(plate: car.plate),
                      if (car.fuel.isNotEmpty ||
                          car.color.isNotEmpty ||
                          car.ownership.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _OfficialSpecs(car: car),
                      ],
                      const SizedBox(height: 14),
                      _ValueInsights(car: car),
                      if (car.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _SellerAbout(text: car.description.trim()),
                      ],
                      const SizedBox(height: 14),
                      // Cross-listing memory: past listings for this plate +
                      // odometer-rollback flag (renders nothing if first time).
                      PlateHistoryCard(
                        plate: car.plate,
                        currentCarId: car.id,
                        currentKm: car.km,
                      ),
                      const SizedBox(height: 16),
                      _SellerCard(sellerType: car.sellerType),
                      const SizedBox(height: 16),
                      // Crowd trust: buyers report who they actually met.
                      SellerEncounterCard(car: car),
                      const SizedBox(height: 12),
                      _HistoryButton(plate: car.plate),
                      const SizedBox(height: 16),
                      // Guided buyer journey — interactive, per-buyer progress.
                      BuyerJourneyCard(carId: car.id),
                      const SizedBox(height: 16),
                      // Crowdsourced visitor notes for this listing.
                      CarNotesSection(carId: car.id),
                      if (car.reasonForSelling.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text('סיבת המכירה',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: context.colors.textPrimary)),
                        const SizedBox(height: 6),
                        Text(car.reasonForSelling,
                            style: TextStyle(
                                color: context.colors.textMuted)),
                      ],
                      const SizedBox(height: 16),
                      // Official records and user reports sit side by side on
                      // this page, so the notice belongs here.
                      const LiabilityNotice(),
                      const SizedBox(height: 8),
                      // The content-removal policy promises a route to report
                      // a whole listing, not just an individual note. This is
                      // it, placed with the other fine print.
                      Center(
                        child: TextButton.icon(
                          icon: const Icon(Icons.flag_outlined, size: 18),
                          label: const Text('דווח על המודעה'),
                          style: TextButton.styleFrom(
                            foregroundColor: context.colors.textMuted,
                          ),
                          onPressed: () =>
                              showReportListing(context, ref, carId: car.id),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        _ActionBar(car: car, isSaved: isSaved),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.car});
  final CarModel car;

  static final _fmt = NumberFormat('#,###', 'en');

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.speed, '${_fmt.format(car.km)} ק"מ'),
      (Icons.event, '${car.year}'),
      (Icons.people_outline, 'יד ${car.hand}'),
      (Icons.place_outlined, car.area),
    ];
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final it in items)
            Column(
              children: [
                Icon(it.$1, color: context.colors.teal, size: 22),
                const SizedBox(height: 4),
                Text(it.$2,
                    style: TextStyle(
                        fontSize: 13, color: context.colors.textPrimary)),
              ],
            ),
        ],
      ),
    );
  }
}

/// Official specs copied from data.gov.il at listing time (fuel/color/owner).
class _OfficialSpecs extends StatelessWidget {
  const _OfficialSpecs({required this.car});
  final CarModel car;

  @override
  Widget build(BuildContext context) {
    final chips = <(IconData, String)>[
      if (car.fuel.isNotEmpty) (Icons.local_gas_station, car.fuel),
      if (car.color.isNotEmpty) (Icons.palette_outlined, car.color),
      if (car.ownership.isNotEmpty) (Icons.badge_outlined, car.ownership),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.tealLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user, size: 16, color: context.colors.teal),
              const SizedBox(width: 6),
              Text('מפרט רשמי · משרד התחבורה',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: context.colors.tealText)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (icon, label) in chips)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 15, color: context.colors.teal),
                      const SizedBox(width: 5),
                      Text(label,
                          style: TextStyle(
                              fontSize: 13, color: context.colors.textPrimary)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Derived value signals (no extra data): average km/year and ownership type.
class _ValueInsights extends StatelessWidget {
  const _ValueInsights({required this.car});
  final CarModel car;

  static final _fmt = NumberFormat('#,###', 'en');

  @override
  Widget build(BuildContext context) {
    final age = DateTime.now().year - car.year;
    final kmPerYear = age <= 0 ? car.km : (car.km / age).round();

    // Israeli average is ~15,000 km/year.
    String kmTag;
    Color kmBg, kmFg;
    if (kmPerYear < 12000) {
      kmTag = 'מתחת לממוצע';
      kmBg = context.colors.tealLight;
      kmFg = context.colors.tealText;
    } else if (kmPerYear <= 18000) {
      kmTag = 'ממוצע';
      kmBg = context.colors.background;
      kmFg = context.colors.textMuted;
    } else {
      kmTag = 'מעל הממוצע';
      kmBg = context.colors.warnBg;
      kmFg = context.colors.warnText;
    }

    final ownership = car.ownership.trim();
    final isPrivate = car.isPrivateOwnership;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_outlined, size: 16, color: context.colors.teal),
              const SizedBox(width: 6),
              Text('תובנות שווי',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: context.colors.textPrimary)),
            ],
          ),
          const SizedBox(height: 10),
          _insightRow(
            context,
            icon: Icons.speed,
            label: 'ק"מ ממוצע לשנה',
            value: '${_fmt.format(kmPerYear)} ק"מ',
            tag: kmTag,
            tagBg: kmBg,
            tagFg: kmFg,
          ),
          if (ownership.isNotEmpty) ...[
            const SizedBox(height: 8),
            _insightRow(
            context,
              icon: Icons.badge_outlined,
              label: 'סוג בעלות',
              value: ownership,
              tag: isPrivate ? 'פרטי ✓' : 'שימוש מסחרי',
              tagBg: isPrivate ? context.colors.tealLight : context.colors.warnBg,
              tagFg: isPrivate ? context.colors.tealText : context.colors.warnText,
            ),
          ],
        ],
      ),
    );
  }

  Widget _insightRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required String tag,
    required Color tagBg,
    required Color tagFg,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.colors.teal),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(fontSize: 13, color: context.colors.textMuted)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration:
              BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(20)),
          child: Text(tag,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.bold, color: tagFg)),
        ),
      ],
    );
  }
}

/// The seller's free-text "a few words about the car".
class _SellerAbout extends StatelessWidget {
  const _SellerAbout({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.format_quote_outlined,
                  size: 16, color: context.colors.teal),
              const SizedBox(width: 6),
              Text('מהמוכר',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: context.colors.textPrimary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(text,
              style: TextStyle(
                  fontSize: 13, height: 1.4, color: context.colors.textPrimary)),
        ],
      ),
    );
  }
}

class _SellerCard extends StatelessWidget {
  const _SellerCard({required this.sellerType});
  final SellerType sellerType;

  String get _subtitle => switch (sellerType) {
        SellerType.private => 'הרכב רשום כבעלות פרטית במרשם',
        SellerType.agent => 'סוכן — מוכר בשם בעל הרכב',
        SellerType.dealer => 'סוחר / מגרש רכב',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.tealLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: context.colors.teal,
                child: Icon(Icons.person, color: context.colors.onBrand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sellerType.label,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: context.colors.tealText)),
                    const SizedBox(height: 2),
                    Text(_subtitle,
                        style: TextStyle(
                            fontSize: 12.5, color: context.colors.tealText2)),
                  ],
                ),
              ),
              SellerTypeBadge(type: sellerType, compact: true),
            ],
          ),
          // States the limits of the check right where the label is read, so
          // the badge can never be mistaken for identity or ownership proof.
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 13, color: context.colors.tealText2),
              const SizedBox(width: 5),
              Expanded(
                child: Text(AppStrings.checkScopeNote,
                    style: TextStyle(
                        fontSize: 11.5, height: 1.35, color: context.colors.tealText2)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryButton extends StatelessWidget {
  const _HistoryButton({required this.plate});
  final String plate;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: context.colors.teal,
        side: BorderSide(color: context.colors.teal),
        minimumSize: const Size.fromHeight(48),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.assignment_outlined),
      label: const Text('היסטוריית רכב רשמית'),
      onPressed: () => context.push('/car/$plate/history'),
    );
  }
}

class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.car, required this.isSaved});
  final CarModel car;
  final bool isSaved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: context.colors.cardBorder)),
        ),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.teal,
                  minimumSize: const Size.fromHeight(50),
                ),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('שלח הודעה'),
                onPressed: () async {
                  // Guests can't open a chat — invite them to sign in.
                  final isGuest =
                      ref.read(authStateProvider).valueOrNull == null;
                  if (isGuest) {
                    ref.read(analyticsHelperProvider).guestPrompt('chat');
                    showLoginRequired(context, action: 'לשלוח הודעה');
                    return;
                  }
                  try {
                    final chatId =
                        await ref.read(openChatForCarProvider).call(car);
                    if (!context.mounted) return;
                    if (chatId == null) {
                      showLoginRequired(context, action: 'לשלוח הודעה');
                      return;
                    }
                    ref.read(analyticsHelperProvider).chatStarted();
                    context.push('/chat/$chatId');
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('לא ניתן לפתוח צ׳אט כרגע. נסה שוב.')),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            _RoundAction(
              icon: Icons.build_outlined,
              onTap: () => context.push('/inspectors/${car.id}'),
            ),
            const SizedBox(width: 8),
            _RoundAction(
              icon: Icons.favorite_border,
              iconWidget: HeartCheckIcon(
                size: 24,
                filled: isSaved,
                color:
                    isSaved ? context.colors.teal : context.colors.textMuted,
                checkColor: context.colors.background,
              ),
              onTap: () {
                // Saving requires an account — prompt guests to sign in.
                final isGuest =
                    ref.read(authStateProvider).valueOrNull == null;
                if (isGuest) {
                  ref.read(analyticsHelperProvider).guestPrompt('save');
                  showLoginRequired(context, action: 'לשמור רכבים');
                  return;
                }
                ref.read(toggleSavedProvider).call(car.id, !isSaved);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction(
      {required this.icon, required this.onTap, this.iconWidget});
  final IconData icon;
  final VoidCallback onTap;

  /// Drawn instead of [icon] when the mark isn't a Material glyph.
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: context.colors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.cardBorder),
        ),
        child: iconWidget ??
            Icon(icon, color: context.colors.textPrimary),
      ),
    );
  }
}
