import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../providers/cars_provider.dart';
import '../../widgets/car_card_widget.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedCarsProvider);
    final savedIds = ref.watch(savedIdsProvider).valueOrNull ?? const {};

    return Scaffold(
      appBar: AppBar(title: const Text('רכבים שמורים')),
      body: SafeArea(
        child: savedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(
            child: Text('שגיאה בטעינת השמורים',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          data: (cars) {
            if (cars.isEmpty) return const _EmptySaved();
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cars.length,
              itemBuilder: (context, i) {
                final car = cars[i];
                return CarCard(
                  car: car,
                  saved: savedIds.contains(car.id),
                  onToggleSave: () =>
                      ref.read(toggleSavedProvider).call(car.id, false),
                  onTap: () => context.push('/car/${car.id}'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _EmptySaved extends StatelessWidget {
  const _EmptySaved();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite_border,
              size: 64, color: AppColors.textSubtle),
          const SizedBox(height: 12),
          const Text('עדיין לא שמרת רכבים',
              style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
            onPressed: () => context.go('/home'),
            child: const Text('עבור לרכבים'),
          ),
        ],
      ),
    );
  }
}
