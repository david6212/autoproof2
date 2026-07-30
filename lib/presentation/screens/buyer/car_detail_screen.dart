import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/car_model.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cars_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/buyer_journey_card.dart';
import '../../widgets/car_notes_section.dart';
import '../../widgets/gov_red_flags_card.dart';
import '../../widgets/login_required_sheet.dart';
import '../../widgets/plate_history_card.dart';
import '../../widgets/seller_encounter_card.dart';
import '../../widgets/seller_type_badge.dart';

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
            const Icon(Icons.error_outline,
                size: 48, color: AppColors.errorRed),
            const SizedBox(height: 12),
            const Text('הרכב לא נמצא',
                style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 12),
            TextButton(
                onPressed: () => context.pop(), child: const Text('חזרה')),
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
              SliverToBoxAdapter(child: _Gallery(car: car)),
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
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '₪${_priceFmt.format(car.price)}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.teal,
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
                        const Text('סיבת המכירה',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 6),
                        Text(car.reasonForSelling,
                            style: const TextStyle(
                                color: AppColors.textMuted)),
                      ],
                      const SizedBox(height: 16),
                      // Official records and user reports sit side by side on
                      // this page, so the notice belongs here.
                      const LiabilityNotice(),
                      const SizedBox(height: 24),
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

class _Gallery extends StatefulWidget {
  const _Gallery({required this.car});
  final CarModel car;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.car.photos;
    return Stack(
      children: [
        SizedBox(
          height: 280,
          width: double.infinity,
          child: photos.isEmpty
              ? Container(
                  color: AppColors.tealLight,
                  child: const Icon(Icons.directions_car,
                      size: 80, color: AppColors.teal),
                )
              : PageView.builder(
                  controller: _controller,
                  itemCount: photos.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => CachedNetworkImage(
                    imageUrl: photos[i],
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.tealLight,
                      child: const Icon(Icons.directions_car,
                          size: 80, color: AppColors.teal),
                    ),
                  ),
                ),
        ),
        // Top scrim so the back button stays legible over bright photos.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.28), Colors.transparent],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: CircleAvatar(
              backgroundColor: AppColors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_forward,
                    color: AppColors.textPrimary),
                onPressed: () => context.pop(),
              ),
            ),
          ),
        ),
        // Photo counter (top-left).
        if (photos.length > 1)
          Positioned(
            top: 16,
            left: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${_index + 1}/${photos.length}',
                  style: const TextStyle(color: AppColors.white, fontSize: 12)),
            ),
          ),
        // Seller-type pill (bottom-right).
        Positioned(
          bottom: 12,
          right: 12,
          child: SellerTypeBadge(type: widget.car.sellerType),
        ),
        // Page dots (bottom-center).
        if (photos.length > 1)
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(photos.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.white
                        : AppColors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
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
                Icon(it.$1, color: AppColors.teal, size: 22),
                const SizedBox(height: 4),
                Text(it.$2,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textPrimary)),
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
        color: AppColors.tealLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user, size: 16, color: AppColors.teal),
              SizedBox(width: 6),
              Text('מפרט רשמי · משרד התחבורה',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.tealText)),
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
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 15, color: AppColors.teal),
                      const SizedBox(width: 5),
                      Text(label,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textPrimary)),
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
      kmBg = AppColors.tealLight;
      kmFg = AppColors.tealText;
    } else if (kmPerYear <= 18000) {
      kmTag = 'ממוצע';
      kmBg = AppColors.background;
      kmFg = AppColors.textMuted;
    } else {
      kmTag = 'מעל הממוצע';
      kmBg = AppColors.warnBg;
      kmFg = AppColors.warnText;
    }

    final ownership = car.ownership.trim();
    final isPrivate = car.isPrivateOwnership;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights_outlined, size: 16, color: AppColors.teal),
              SizedBox(width: 6),
              Text('תובנות שווי',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 10),
          _insightRow(
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
              icon: Icons.badge_outlined,
              label: 'סוג בעלות',
              value: ownership,
              tag: isPrivate ? 'פרטי ✓' : 'שימוש מסחרי',
              tagBg: isPrivate ? AppColors.tealLight : AppColors.warnBg,
              tagFg: isPrivate ? AppColors.tealText : AppColors.warnText,
            ),
          ],
        ],
      ),
    );
  }

  Widget _insightRow({
    required IconData icon,
    required String label,
    required String value,
    required String tag,
    required Color tagBg,
    required Color tagFg,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.teal),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
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
          const Row(
            children: [
              Icon(Icons.format_quote_outlined,
                  size: 16, color: AppColors.teal),
              SizedBox(width: 6),
              Text('מהמוכר',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(text,
              style: const TextStyle(
                  fontSize: 13.5, height: 1.4, color: AppColors.textPrimary)),
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
        color: AppColors.tealLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.teal,
                child: Icon(Icons.person, color: AppColors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sellerType.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.tealText)),
                    const SizedBox(height: 2),
                    Text(_subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.tealText2)),
                  ],
                ),
              ),
              SellerTypeBadge(type: sellerType, compact: true),
            ],
          ),
          // States the limits of the check right where the label is read, so
          // the badge can never be mistaken for identity or ownership proof.
          const SizedBox(height: 10),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 13, color: AppColors.tealText2),
              SizedBox(width: 5),
              Expanded(
                child: Text(AppStrings.checkScopeNote,
                    style: TextStyle(
                        fontSize: 11, height: 1.35, color: AppColors.tealText2)),
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
        foregroundColor: AppColors.teal,
        side: const BorderSide(color: AppColors.teal),
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
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.cardBorder)),
        ),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
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
              icon: isSaved ? Icons.favorite : Icons.favorite_border,
              color: isSaved ? AppColors.errorRed : AppColors.textMuted,
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
  const _RoundAction({required this.icon, required this.onTap, this.color});
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Icon(icon, color: color ?? AppColors.textPrimary),
      ),
    );
  }
}
