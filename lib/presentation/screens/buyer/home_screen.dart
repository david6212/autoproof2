import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/car_model.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cars_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/car_card_widget.dart';
import '../../widgets/fact_chip.dart';
import '../../widgets/login_required_sheet.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/search_filter_sheet.dart';
import '../../widgets/skeleton.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _filters = [
    'הכל',
    'משפחתי',
    'קרוסאובר',
    'היברידי',
    'חשמלי',
    'ספורט',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carsAsync = ref.watch(filteredCarsProvider);
    final filters = ref.watch(carFiltersProvider);
    final query = ref.watch(carSearchProvider);
    final savedIds = ref.watch(savedIdsProvider).valueOrNull ?? const {};
    final filtering = !filters.isDefault || query.trim().isNotEmpty;

    void toggleType(String f) {
      final types = {...filters.types};
      if (f == 'הכל') {
        types.clear();
      } else if (types.contains(f)) {
        types.remove(f);
      } else if (types.length < 4) {
        types.add(f);
      }
      ref.read(carFiltersProvider.notifier).state =
          filters.copyWith(types: types);
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(),
            _FilterPills(
              filters: _filters,
              selectedTypes: filters.types,
              onToggle: toggleType,
            ),
            Expanded(
              child: carsAsync.when(
                loading: () => const CarListSkeleton(),
                error: (e, _) => _ErrorState(
                  onRetry: () => ref.invalidate(activeCarsProvider),
                ),
                data: (cars) => cars.isEmpty
                    ? _EmptyState(
                        filtering: filtering,
                        onClear: () {
                          ref.read(carFiltersProvider.notifier).state =
                              const CarFilters();
                          ref.read(carSearchProvider.notifier).state = '';
                        },
                      )
                    : _CarList(cars: cars, savedIds: savedIds),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The top of Home: the mark, the two utility actions, and search.
///
/// This used to be a solid teal band carrying a slogan in large white bold.
/// It was the loudest thing on the screen and it competed with the listings,
/// which are the reason anyone opens the app. It now sits on the page colour
/// and lets the brand mark do the identifying.
///
/// The mark is deliberately small — 26px of emblem against an 18px wordmark.
/// A home screen does not have to announce which app it is; the person opening
/// it already knows.
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      // A faint wash, now that the app bar is no longer a green band. It gives
      // the top of Home an edge without shouting, and the search pill sitting
      // on it reads as a control rather than dissolving into the page.
      color: context.colors.headerTint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const BrandLogo(size: 26),
              const SizedBox(width: AppSpace.sm),
              const BrandWordmark(fontSize: 18),
              const Spacer(),
              _HeaderButton(
                icon: Icons.info_outline,
                tooltip: 'אודות BonnetCheck',
                onTap: () => context.push('/about'),
              ),
              const SizedBox(width: AppSpace.sm),
              const _NotificationBell(),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          const _SearchCard(),
        ],
      ),
    );
  }
}

/// A utility action in the header: a white rounded square on the tint, rather
/// than a bare glyph. On a tinted band a plain icon reads as decoration; a
/// surface behind it says it can be pressed.
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  static const size = 38.0;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: context.colors.cardBorder),
            ),
            child: Icon(icon, size: 19, color: context.colors.textMuted),
          ),
        ),
      ),
    );
  }
}

/// Bell with a count of genuinely unread messages. No badge when there are
/// none — the count comes from chat documents, never from a placeholder.
class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadCountProvider);

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        _HeaderButton(
          icon: Icons.notifications_none,
          tooltip: 'התראות',
          onTap: () => context.push('/notifications'),
        ),
        if (count > 0)
          // Pinned to the button's own corner. It used to sit inside an
          // IconButton's 48px touch area, which is bigger than the visible
          // square — so the dot floated away from the bell it belongs to.
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16),
              decoration: BoxDecoration(
                color: context.colors.errorRed,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                count > 9 ? '9+' : '$count',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: context.colors.onBrand,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}

/// The white panel on the tinted header: what the screen is for, the live
/// search field, and shortcuts into the three filters people actually reach
/// for.
///
/// **The reference design's version is a form** — area, price, years and a
/// "חיפוש" button that produces results. This one keeps the app's live
/// filtering: the list below is already the answer and updates as you type, so
/// a submit button would be a control that does nothing.
///
/// The reference also carries a "רק רכבים עם נתונים רשמיים" toggle. That is
/// dropped rather than drawn: every listing here is created from a plate
/// lookup, so the switch would be a no-op — and worse, offering it implies
/// some listings have no official data behind them.
class _SearchCard extends ConsumerWidget {
  const _SearchCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(carFiltersProvider);

    void openFilters() => showSearchFilterSheet(
          context,
          ref.read(activeCarsProvider).valueOrNull ?? const [],
        );

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md + 2),
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('חיפוש רכב', style: AppText.subtitle),
              const SizedBox(width: AppSpace.xs + 2),
              Icon(Icons.auto_awesome, size: 14, color: context.colors.teal),
            ],
          ),
          const SizedBox(height: AppSpace.xxs),
          Text('מצאו את הרכב הבא שלכם, ללא הפתעות',
              style: context.text.micro),
          const SizedBox(height: AppSpace.md),
          const _SearchField(),
          const SizedBox(height: AppSpace.sm + 2),
          // One row, three shortcuts. The reference stacks them over two rows
          // plus a toggle; on a browse-first screen that pushes the cars —
          // which are the reason anyone opened the app — off the fold.
          Row(
            children: [
              Expanded(
                child: _QuickFilter(
                  icon: Icons.place_outlined,
                  label: f.area ?? 'אזור',
                  on: f.area != null,
                  onTap: openFilters,
                ),
              ),
              const SizedBox(width: AppSpace.sm - 2),
              Expanded(
                child: _QuickFilter(
                  icon: Icons.payments_outlined,
                  label: f.maxPrice < CarFilters.priceCap
                      ? 'עד ${(f.maxPrice / 1000).round()} אלף'
                      : 'מחיר',
                  on: f.maxPrice < CarFilters.priceCap,
                  onTap: openFilters,
                ),
              ),
              const SizedBox(width: AppSpace.sm - 2),
              Expanded(
                child: _QuickFilter(
                  icon: Icons.event_outlined,
                  label: f.minYear > CarFilters.yearFloor
                      ? 'מ-${f.minYear}'
                      : 'שנה',
                  on: f.minYear > CarFilters.yearFloor,
                  onTap: openFilters,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One shortcut into the filter sheet, showing its current value when set.
class _QuickFilter extends StatelessWidget {
  const _QuickFilter({
    required this.icon,
    required this.label,
    required this.on,
    required this.onTap,
  });

  final IconData icon;
  final String label;

  /// Whether this filter is actually narrowing anything. A set filter has to
  /// look different from an empty one, or the row reads as three buttons that
  /// never respond.
  final bool on;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
        decoration: BoxDecoration(
          color: on ? context.colors.tealLight : context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: on ? context.colors.tealLight : context.colors.cardBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 14,
                color: on ? context.colors.tealText : context.colors.teal),
            const SizedBox(width: AppSpace.xs + 1),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: on ? FontWeight.bold : FontWeight.normal,
                  color:
                      on ? context.colors.tealText : context.colors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live search box that filters the car list by make/model/area/plate.
class _SearchField extends ConsumerStatefulWidget {
  const _SearchField();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _set(String v) {
    ref.read(carSearchProvider.notifier).state = v;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(carFiltersProvider).activeCount;

    // One pill holding search and filter, rather than a field plus a separate
    // 52px square beside it. They are two halves of one question — "which
    // cars?" — and the square was reading as an unrelated third control.
    return Container(
      height: 48,
      padding: const EdgeInsetsDirectional.only(start: 14, end: 4),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        // On the old teal band, being borderless white was enough to define
        // the field. On the page colour it needs an edge or it dissolves.
        border: Border.all(color: context.colors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 20, color: context.colors.textSubtle),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onChanged: _set,
              style: AppText.body,
              decoration: InputDecoration.collapsed(
                hintText: 'חיפוש לפי יצרן, דגם, אזור או מספר רכב',
                hintStyle: AppText.body.copyWith(
                  color: context.colors.textSubtle,
                ),
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: context.colors.textSubtle,
              tooltip: 'נקה חיפוש',
              onPressed: () {
                _controller.clear();
                _set('');
              },
            ),
          _FilterButton(
            count: count,
            onTap: () => showSearchFilterSheet(
              context,
              ref.read(activeCarsProvider).valueOrNull ?? const [],
            ),
          ),
        ],
      ),
    );
  }
}

/// Square button that opens the filter sheet, with an active-count badge.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: count > 0 ? 'סינון · $count מסננים פעילים' : 'סינון',
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        // No chrome of its own — it lives inside the search pill now.
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.tune, size: 20, color: context.colors.textPrimary),
              if (count > 0)
                PositionedDirectional(
                  top: 3,
                  end: 3,
                  // Teal, not red. A filter count is a state the user chose,
                  // not a fault — red made "2 filters on" look like an error.
                  child: Container(
                    width: 15,
                    height: 15,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.colors.teal,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: context.colors.onBrand,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterPills extends StatelessWidget {
  const _FilterPills({
    required this.filters,
    required this.selectedTypes,
    required this.onToggle,
  });

  final List<String> filters;
  final Set<String> selectedTypes;
  final void Function(String) onToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = filters[i];
          final isActive = (selectedTypes.isEmpty && f == 'הכל') ||
              selectedTypes.contains(f);
          return GestureDetector(
            onTap: () => onToggle(f),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive ? context.colors.teal : context.colors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isActive ? context.colors.teal : context.colors.cardBorder,
                ),
              ),
              child: Text(
                f,
                style: TextStyle(
                  color: isActive ? context.colors.onBrand : context.colors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CarList extends StatelessWidget {
  const _CarList({required this.cars, required this.savedIds});

  final List<CarModel> cars;
  final Set<String> savedIds;

  @override
  Widget build(BuildContext context) {
    return CarListView(
      cars: cars,
      // A section heading rather than a grey count line: the list is the
      // subject of the screen, and a heading says so. The count moves to the
      // end of the row, where it reads as a fact about the section instead of
      // as the section's name.
      header: SectionHeader(
        title: 'רכבים בקרבתך',
        actionLabel: '${cars.length} תוצאות',
        onAction: null,
      ),
      cardBuilder: (car) => Consumer(builder: (context, ref, _) {
        return CarCard(
          car: car,
          saved: savedIds.contains(car.id),
          onToggleSave: () {
            // Guests can't save — invite them to sign in.
            if (ref.read(authStateProvider).valueOrNull == null) {
              ref.read(analyticsHelperProvider).guestPrompt('save');
              showLoginRequired(context, action: 'לשמור רכבים');
              return;
            }
            ref
                .read(toggleSavedProvider)
                .call(car.id, !savedIds.contains(car.id));
          },
          onTap: () => context.push('/car/${car.id}'),
        );
      }),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.filtering = false, this.onClear});

  final bool filtering;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(filtering ? Icons.search_off : Icons.directions_car_outlined,
              size: 64, color: context.colors.textSubtle),
          const SizedBox(height: 12),
          Text(
            filtering ? 'לא נמצאו רכבים תואמים' : 'אין רכבים להצגה כרגע',
            style: TextStyle(color: context.colors.textMuted),
          ),
          if (filtering && onClear != null) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('נקה חיפוש וסינון'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: context.colors.errorRed),
          const SizedBox(height: 12),
          Text(AppStrings.errorGeneric,
              style: TextStyle(color: context.colors.textMuted)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text(AppStrings.retry)),
        ],
      ),
    );
  }
}
