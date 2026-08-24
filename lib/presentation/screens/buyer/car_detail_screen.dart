import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/car_model.dart';
import '../../../app/router.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cars_provider.dart';
import '../../providers/chat_provider.dart';
import '../../../core/utils/odometer_check.dart';
import '../../../data/models/gov_data_model.dart';
import '../../providers/gov_api_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/car/car_active_warnings.dart';
import '../../widgets/car/demo_listing_notice.dart';
import '../../widgets/common/collapsible_section.dart';
import '../../widgets/share_listing_button.dart';
import '../../widgets/buyer_journey_card.dart';
import '../../widgets/car_notes_section.dart';
import '../../widgets/car_photo_gallery.dart';
import '../../widgets/login_required_sheet.dart';
import '../../widgets/plate_history_card.dart';
import '../../widgets/report_listing_sheet.dart';
import '../../widgets/seller_type_badge.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../widgets/fact_chip.dart';
import '../../widgets/saved_check_icon.dart';
import '../../widgets/spec_tile.dart';
import '../../widgets/documented_history_card.dart';
import '../../widgets/market_price_band.dart';
import '../../widgets/error_retry.dart';

class CarDetailScreen extends ConsumerWidget {
  const CarDetailScreen({super.key, required this.carId});

  final String carId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carAsync = ref.watch(carByIdProvider(carId));

    return carAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      // A failed load is not a missing car. Saying "not found" for a lost
      // second of signal tells the reader the listing is gone.
      error: (_, __) => Scaffold(
        appBar: AppBar(),
        body: ErrorRetry(
          message: 'לא הצלחנו לטעון את המודעה',
          onRetry: () => ref.invalidate(carByIdProvider(carId)),
        ),
      ),
      data: (car) => car == null ? _error(context) : _Content(car: car),
    );
  }

  Widget _error(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
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
      ),
    );
  }
}

class _Content extends ConsumerStatefulWidget {
  const _Content({required this.car});
  final CarModel car;

  @override
  ConsumerState<_Content> createState() => _ContentState();
}

class _ContentState extends ConsumerState<_Content> {
  static final _priceFmt = NumberFormat('#,###', 'en');

  final _scroll = ScrollController();

  /// Marks the odometer panel so the finding at the top can send the reader to
  /// the evidence instead of restating it.
  final _odometerKey = GlobalKey();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToOdometer() {
    final target = _odometerKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: 0.1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final car = widget.car;
    final savedIds = ref.watch(savedIdsProvider).valueOrNull ?? const {};
    final isSaved = savedIds.contains(car.id);

    return Scaffold(
      // The photo used to be the top of the screen and carried the back arrow
      // with it. It now sits below the findings, so the navigation moved into
      // a real app bar — a back arrow half a screen down is not a back arrow.
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'חזרה',
          onPressed: () => popOrHome(context),
        ),
        actions: [ShareListingButton(car: car)],
      ),
      bottomNavigationBar: _ActionBar(car: car, isSaved: isSaved),
      body: SafeArea(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            // ---- LEVEL 1 · could stop a purchase --------------------------
            //
            // Findings first. Everything on this page was equally weighted
            // before, which handed the sorting work to a reader who is about
            // to spend tens of thousands of shekels. Nothing is hidden by
            // this order; it just stops pretending the tyre width and a
            // mileage mismatch deserve the same glance.
            // Above the findings, because a finding about an invented car is
            // not a finding. Everything below this line is fiction on a demo
            // listing, including the price.
            DemoListingNotice(car: car),
            CarActiveWarnings(
              car: car,
              onShowOdometerSource: _scrollToOdometer,
            ),
            Row(
              children: [
                Expanded(child: Text(car.title, style: AppText.h1)),
                Text(
                  '₪${_priceFmt.format(car.price)}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: context.colors.tealText2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _StatsRow(car: car),
            const SizedBox(height: 14),
            _SellerCard(sellerType: car.sellerType),

            // ---- LEVEL 2 · affects price and decision --------------------
            //
            // One card, one weight, one header style, all the way down. What
            // marks level 1 out is that it looks different, not that it looks
            // bigger.
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: CarPhotoGallery(car: car, chrome: false),
            ),
            if (car.fuel.isNotEmpty ||
                car.color.isNotEmpty ||
                car.ownership.isNotEmpty) ...[
              const SizedBox(height: 14),
              _OfficialSpecs(car: car),
            ],
            const SizedBox(height: 14),
            _RegistryAsOf(car: car),
            _RegistryUnreachableNote(car: car),
            _ChecksPerformedNote(car: car),
            _ValueInsights(car: car),
            const SizedBox(height: 14),
            // Silent until there are 8 comparable listings, which with four
            // demo cars means silent today.
            MarketPriceBand(car: car),
            // The seller's own service log, when this listing came from a
            // passport. Renders nothing otherwise — most listings do not, and
            // saying so would read as an accusation rather than an absence.
            DocumentedHistoryCard(car: car),
            // The evidence behind the odometer finding above, which links
            // here rather than repeating itself.
            KeyedSubtree(
              key: _odometerKey,
              child: PlateHistoryCard(car: car, showRollbackBanner: false),
            ),
            if (car.description.trim().isNotEmpty ||
                car.reasonForSelling.isNotEmpty) ...[
              const SizedBox(height: 14),
              _SellerAbout(
                text: car.description.trim(),
                reason: car.reasonForSelling.trim(),
              ),
            ],
            const SizedBox(height: 14),
            // Crowdsourced visitor notes for this listing.
            CarNotesSection(carId: car.id),

            // ---- LEVEL 3 · background, folded away -----------------------
            //
            // Every one of these keeps a summary while closed, so nobody has
            // to open a section to discover they did not want it.
            const SizedBox(height: 24),
            _HistoryButton(carId: car.id),
            const SizedBox(height: 14),
            BuyerJourneyCard(carId: car.id, collapsible: true),
            const SizedBox(height: 14),
            CollapsibleSection(
              icon: Icons.gavel_outlined,
              title: 'הבהרה משפטית ודיווח',
              summary: 'מקורות הנתונים, ודיווח על מודעה',
              persistKey: 'legal',
              child: Column(
                children: [
                  const LiabilityNotice(),
                  const SizedBox(height: 8),
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
                ],
              ),
            ),
          ],
        ),
      ),
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

  /// Engine, as one readable line: the fuel and the capacity together
  /// (`בנזין 1998 סמ"ק`). Electric models have no capacity at all, so they
  /// simply read `חשמלי` rather than claiming a missing number.
  String? _engine() {
    final cc = car.spec?.engineCc;
    if (car.fuel.isEmpty && cc == null) return null;
    if (cc == null) return car.fuel;
    return '${car.fuel} $cc סמ"ק'.trim();
  }

  @override
  Widget build(BuildContext context) {
    final spec = car.spec;
    final engine = _engine();

    final tiles = <SpecTile>[
      if (engine != null)
        SpecTile(
            icon: Icons.local_gas_station_outlined,
            label: 'סוג מנוע',
            value: engine),
      if (spec?.seats != null)
        SpecTile(
            icon: Icons.event_seat_outlined,
            label: 'מקומות ישיבה',
            value: '${spec!.seats} מושבים'),
      if (spec != null)
        SpecTile(
            icon: Icons.settings_outlined,
            label: 'תיבת הילוכים',
            value: spec.automatic ? 'אוטומטית' : 'ידנית'),
      if (spec?.drivetrain.isNotEmpty ?? false)
        SpecTile(
            icon: Icons.route_outlined, label: 'הנעה', value: spec!.drivetrain),
      if (car.color.isNotEmpty)
        SpecTile(
            icon: Icons.palette_outlined, label: 'צבע', value: car.color),
      if (car.ownership.isNotEmpty)
        SpecTile(
            icon: Icons.badge_outlined, label: 'בעלות', value: car.ownership),
    ];

    if (tiles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'מפרט הרכב'),
        const SizedBox(height: AppSpace.sm - 2),
        // The provenance stays attached to the specs. It used to be carried by
        // the green wash the tiles replaced, and dropping it would leave
        // official figures looking like something the seller typed in. On a
        // demo listing these figures ARE something someone typed in, and the
        // badge says which.
        DataSourceBadge(
          source: car.isDemo ? DataSource.demo : DataSource.official,
        ),
        const SizedBox(height: AppSpace.md),
        SpecTileGrid(tiles: tiles),
      ],
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
              tag: isPrivate ? 'פרטי' : 'שימוש מסחרי',
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
/// The seller's own words.
///
/// Absorbed the separate "סיבת המכירה" panel, which said the same kind of
/// thing one card further down and counted as its own section in a page that
/// had seventeen.
class _SellerAbout extends StatelessWidget {
  const _SellerAbout({required this.text, this.reason = ''});
  final String text;
  final String reason;

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
          if (text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(text,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: context.colors.textPrimary)),
          ],
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('סיבת המכירה',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: context.colors.textPrimary)),
            const SizedBox(height: 2),
            Text(reason, style: context.text.caption),
          ],
        ],
      ),
    );
  }
}

class _SellerCard extends StatelessWidget {
  const _SellerCard({required this.sellerType});
  final SellerType sellerType;

  /// All three describe what the SELLER said, never what the registry says.
  ///
  /// The private line used to read "הרכב רשום כבעלות פרטית במרשם",
  /// which is a claim about a state record — and `sellerType` is a radio
  /// button the seller picks when publishing. `AppStrings.checkScopeNote`,
  /// printed ten lines below it in the same card, already said the opposite:
  /// "המוכר סומן לפי הסיווג שבחר. לא אימתנו את זהותו ולא את בעלותו על הרכב."
  ///
  /// The registry's own ownership class has its own row, in תובנות שווי,
  /// where it is read from the lookup rather than from a form.
  String get _subtitle => switch (sellerType) {
        SellerType.private => 'המוכר מסר שהרכב שלו',
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
                backgroundColor: context.colors.tealFill,
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
  const _HistoryButton({required this.carId});

  /// The listing id. It used to be the plate, which put the number in the
  /// address bar of every buyer who tapped through — and in any link they
  /// then shared.
  final String carId;

  @override
  Widget build(BuildContext context) {
    // A record row rather than an outlined button: it goes to a page of
    // official records, and it now sits among tiles and rows that all lead
    // somewhere. A second full-width button here competed with the one in the
    // action bar, which is the screen's actual primary action.
    return RecordRow(
      icon: Icons.assignment_outlined,
      label: 'היסטוריית רכב רשמית',
      value: 'ק"מ בטסט, טסט, בעלויות וריקולים',
      onTap: () => context.push('/car/$carId/history'),
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
                  backgroundColor: context.colors.tealFill,
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
              icon: Icons.check_rounded,
              iconWidget: SavedCheckIcon(
                size: 24,
                filled: isSaved,
                color:
                    isSaved ? context.colors.teal : context.colors.textMuted,
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
                ref
                    .read(toggleSavedProvider)
                    .call(car.id, !isSaved, price: car.price);
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

/// What was checked, when nothing came back.
///
/// This replaced a green banner with a verified-shield icon reading "אין דגלים
/// אדומים רשמיים". The wording there was careful — it spoke about the records,
/// not the car — but it was the most prominent thing on the page, and what it
/// looked like was approval. Absence of a record is not a clean bill of
/// health, and the app cannot afford to be read as saying otherwise.
///
/// Deleting it outright was the other option. It loses something real: the
/// five-dataset check is most of what separates this from a classifieds board,
/// and a buyer has no way to know it happened. So the fact survives, and
/// everything that made it look like a verdict is gone — grey micro type, no
/// icon, no fill, and a closing clause that says what it is not.
///
/// When the registry data on this listing was taken.
///
/// Shown always, and never rounded to "recently". The buyer is looking at a
/// stored answer rather than a live one — that is the price of not handing
/// every visitor the plate — and a stored answer presented without its date
/// is the same claim as a live one.
class _RegistryAsOf extends StatelessWidget {
  const _RegistryAsOf({required this.car});

  final CarModel car;

  @override
  Widget build(BuildContext context) {
    final at = car.govCheckedAt;
    if (at == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        'נתוני מרשם הרכב נבדקו ב-${DateFormatter.format(at)}. '
        'המוכר יכול לרענן אותם.',
        style: context.text.micro,
      ),
    );
  }
}

/// Renders nothing until the registry answers, and nothing at all when there
/// are findings: they are already at the top of the page, and a line about
/// what was clean underneath them would read as an argument with them.
class _ChecksPerformedNote extends ConsumerWidget {
  const _ChecksPerformedNote({required this.car});

  final CarModel car;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gov = listingGov(ref, car).valueOrNull;
    if (gov == null) return const SizedBox.shrink();

    final officialKm = OdometerCheck.officialReading(gov.lastTestKm);
    final anyFinding = gov.offRoad ||
        gov.structuralChange ||
        gov.recalls.isNotEmpty ||
        OdometerCheck.belowOfficial(
            officialKm: officialKm, currentKm: car.km);
    if (anyFinding) return const SizedBox.shrink();

    // Name only the datasets that actually answered. Any endpoint can fail on
    // its own, and listing a check we never completed would be the exact claim
    // this line exists to avoid making.
    final checked = <String>[
      if (gov.answered(GovDataset.history)) 'שינוי מבנה',
      if (gov.answered(GovDataset.recalls)) 'קריאת שירות פתוחה',
      if (gov.answered(GovDataset.offRoad)) 'ירידה מהכביש',
    ];

    // Every dataset failed, so there is nothing to report having checked.
    if (checked.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'נבדקו מאגרי משרד התחבורה. לא נמצאו בהם רישומי '
            '${_list(checked)}. היעדר רישום אינו אישור לתקינות הרכב.',
            style: context.text.micro,
          ),
          if (gov.missingDatasets.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'חלק ממאגרי משרד התחבורה לא נענו בבדיקה הזאת, '
              'ולכן אין לנו מה לומר עליהם.',
              style: context.text.micro,
            ),
          ],
        ],
      ),
    );
  }

  /// "א, ב ו-ג" — Hebrew list punctuation, so a shrunken list still reads.
  static String _list(List<String> items) {
    if (items.length == 1) return items.first;
    return '${items.take(items.length - 1).join(', ')} ו${items.last}';
  }
}


/// Says so when the registry could not be reached.
///
/// Before this, an outage was invisible: the odometer comparison, the recall
/// check and the official spec simply were not on the page, and nothing said
/// why. On an app whose entire argument is "here is what the state records
/// say", silence is the worst available answer — the reader cannot tell a car
/// with no history from a lookup that never happened, and neither can they
/// tell that trying again might work.
///
/// Deliberately quiet: one line and a retry, in muted type. It is a report on
/// our own plumbing, not a finding about the car, and it must not compete with
/// the ones that are.
class _RegistryUnreachableNote extends ConsumerWidget {
  const _RegistryUnreachableNote({required this.car});

  final CarModel car;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A listing with a stored answer has nothing to be unreachable about —
    // the data came with it.
    if (car.govSnapshot != null) return const SizedBox.shrink();
    // Neither has one with no plate to look up. `cars/{id}` stopped carrying
    // the plate when it went to the seller-only subdocument, so every listing
    // published before snapshots — and every demo listing, whose plate is
    // registered to nobody — arrives here with an empty string. The provider
    // fails on it, and the reader was told the registry could not be reached
    // and offered a retry that could never succeed. Blaming our own plumbing
    // for something that never happened is the same false claim as blaming
    // the car.
    if (car.plate.isEmpty) return const SizedBox.shrink();
    final lookup = ref.watch(govDataForPlateProvider(car.plate));
    if (!lookup.hasError) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: context.colors.background,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: context.colors.cardBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 16, color: context.colors.textSubtle),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(
                'לא הצלחנו להגיע למרשם הרכב, ולכן הנתונים הרשמיים אינם '
                'מוצגים כאן. זה לא אומר דבר על הרכב עצמו.',
                style: context.text.micro,
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
                foregroundColor: context.colors.tealText2,
              ),
              onPressed: () =>
                  ref.invalidate(govDataForPlateProvider(car.plate)),
              child: const Text('נסו שוב', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
