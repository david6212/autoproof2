import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/car_model.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cars_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/car_card_widget.dart';
import '../../widgets/login_required_sheet.dart';
import '../../widgets/search_filter_sheet.dart';

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
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
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

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(color: AppColors.teal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user, color: AppColors.white, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  AppStrings.onlyPrivateSellers,
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, color: AppColors.white),
                tooltip: 'אודות OtoV',
                onPressed: () => context.push('/about'),
              ),
              const _NotificationBell(),
            ],
          ),
          const SizedBox(height: 4),
          const _SearchField(),
        ],
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
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none, color: AppColors.white),
          tooltip: 'התראות',
          onPressed: () => context.push('/notifications'),
        ),
        if (count > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16),
              decoration: BoxDecoration(
                color: AppColors.errorRed,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                count > 9 ? '9+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
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
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onChanged: _set,
            decoration: InputDecoration(
              hintText: 'חפש יצרן, דגם או אזור',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        _controller.clear();
                        _set('');
                      },
                    ),
              filled: true,
              fillColor: AppColors.white,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _FilterButton(
          count: count,
          onTap: () => showSearchFilterSheet(
            context,
            ref.read(activeCarsProvider).valueOrNull ?? const [],
          ),
        ),
      ],
    );
  }
}

/// White square button that opens the filter sheet, with an active-count badge.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.tune, color: AppColors.teal),
            if (count > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.errorRed,
                    shape: BoxShape.circle,
                  ),
                  child: Text('$count',
                      style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold)),
                ),
              ),
          ],
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
                color: isActive ? AppColors.teal : AppColors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isActive ? AppColors.teal : AppColors.cardBorder,
                ),
              ),
              child: Text(
                f,
                style: TextStyle(
                  color: isActive ? AppColors.white : AppColors.textMuted,
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
      header: Text(
        '${cars.length} רכבים בקרבתך',
        style: const TextStyle(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
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
              size: 64, color: AppColors.textSubtle),
          const SizedBox(height: 12),
          Text(
            filtering ? 'לא נמצאו רכבים תואמים' : 'אין רכבים להצגה כרגע',
            style: const TextStyle(color: AppColors.textMuted),
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
          const Icon(Icons.error_outline, size: 48, color: AppColors.errorRed),
          const SizedBox(height: 12),
          const Text(AppStrings.errorGeneric,
              style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text(AppStrings.retry)),
        ],
      ),
    );
  }
}
