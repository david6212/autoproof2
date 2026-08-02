import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cars_provider.dart';
import '../../widgets/car_card_widget.dart';
import '../../widgets/guest_prompt_view.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(authStateProvider).valueOrNull == null;
    final savedAsync = ref.watch(savedCarsProvider);
    final savedIds = ref.watch(savedIdsProvider).valueOrNull ?? const {};

    return Scaffold(
      appBar: AppBar(title: const Text('רכבים שמורים')),
      body: SafeArea(
        child: isGuest
            ? const GuestPromptView(
                icon: Icons.favorite_border,
                title: 'שמור רכבים שאהבת',
                body: 'התחבר כדי לשמור רכבים ולחזור אליהם בקלות.',
              )
            : savedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Text('שגיאה בטעינת השמורים',
                style: TextStyle(color: context.colors.textMuted)),
          ),
          data: (cars) {
            if (cars.isEmpty) return const _EmptySaved();
            return CarListView(
              cars: cars,
              padding: const EdgeInsets.all(16),
              cardBuilder: (car) => CarCard(
                car: car,
                saved: savedIds.contains(car.id),
                onToggleSave: () =>
                    ref.read(toggleSavedProvider).call(car.id, false),
                onTap: () => context.push('/car/${car.id}'),
              ),
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
          Icon(Icons.favorite_border,
              size: 64, color: context.colors.textSubtle),
          const SizedBox(height: 12),
          Text('עדיין לא שמרת רכבים',
              style: TextStyle(color: context.colors.textMuted)),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.teal),
            onPressed: () => context.go('/home'),
            child: const Text('עבור לרכבים'),
          ),
        ],
      ),
    );
  }
}
