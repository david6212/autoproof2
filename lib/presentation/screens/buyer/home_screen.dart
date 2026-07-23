import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/car_model.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cars_provider.dart';
import '../../widgets/car_card_widget.dart';
import '../../widgets/login_required_sheet.dart';

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
    final selected = ref.watch(carFilterProvider);
    final savedIds = ref.watch(savedIdsProvider).valueOrNull ?? const {};

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(),
            _FilterPills(
              filters: _filters,
              selected: selected,
              onSelect: (f) => ref.read(carFilterProvider.notifier).state =
                  f == 'הכל' ? null : f,
            ),
            Expanded(
              child: carsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorState(
                  onRetry: () => ref.invalidate(activeCarsProvider),
                ),
                data: (cars) => cars.isEmpty
                    ? const _EmptyState()
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
                icon: const Icon(Icons.notifications_none,
                    color: AppColors.white),
                onPressed: () => context.push('/notifications'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            decoration: InputDecoration(
              hintText: 'חפש יצרן, דגם או אזור',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppColors.white,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPills extends StatelessWidget {
  const _FilterPills({
    required this.filters,
    required this.selected,
    required this.onSelect,
  });

  final List<String> filters;
  final String? selected;
  final void Function(String) onSelect;

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
          final isActive = (selected == null && f == 'הכל') || selected == f;
          return GestureDetector(
            onTap: () => onSelect(f),
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
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: cars.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '${cars.length} רכבים בקרבתך',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }
        final car = cars[i - 1];
        return Consumer(builder: (context, ref, _) {
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
        });
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car_outlined,
              size: 64, color: AppColors.textSubtle),
          SizedBox(height: 12),
          Text('אין רכבים להצגה כרגע',
              style: TextStyle(color: AppColors.textMuted)),
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
