import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/car_compare.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cars_provider.dart';
import '../../providers/compare_provider.dart';
import '../../widgets/app_bar_action.dart';
import '../../widgets/car_card_widget.dart';
import '../../widgets/guest_prompt_view.dart';
import '../../widgets/saved_check_icon.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/error_retry.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(authStateProvider).valueOrNull == null;
    final savedAsync = ref.watch(savedCarsProvider);
    final savedIds = ref.watch(savedIdsProvider).valueOrNull ?? const {};
    final comparing = ref.watch(compareModeProvider);
    // How much each saved listing has come down since it was saved. Local to
    // this device — noticing a change while the app is shut needs a server.
    final drops = ref.watch(priceDropsProvider).valueOrNull ?? const {};
    final picked = ref.watch(compareSelectionProvider);

    // Only offer the comparison once there is something to compare.
    final canCompare = (savedAsync.valueOrNull?.length ?? 0) >= 2;

    return Scaffold(
      appBar: AppBar(
        title: Text(comparing ? 'בחרו רכבים להשוואה' : 'רכבים שמורים'),
        actions: [
          if (!isGuest && canCompare)
            AppBarAction(
              icon: comparing ? Icons.close : Icons.compare_arrows,
              label: comparing ? 'ביטול' : 'השוואה',
              onPressed: () {
                final next = !comparing;
                ref.read(compareModeProvider.notifier).state = next;
                // Leaving the mode drops the picks, so returning later starts
                // clean rather than resuming a choice made minutes ago.
                if (!next) {
                  ref.read(compareSelectionProvider.notifier).clear();
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: isGuest
            ? GuestPromptView(
                icon: Icons.check_rounded,
                iconWidget:
                    SavedCheckIcon(size: 40, color: context.colors.teal),
                title: 'שמור רכבים שאהבת',
                body: 'התחבר כדי לשמור רכבים ולחזור אליהם בקלות.',
              )
            : savedAsync.when(
                loading: () =>
                    const CarListSkeleton(padding: EdgeInsets.all(16)),
                error: (_, __) => ErrorRetry(
                  message: 'לא הצלחנו לטעון את השמורים',
                  onRetry: () => ref.invalidate(savedCarsProvider),
                ),
                data: (cars) {
                  if (cars.isEmpty) return const _EmptySaved();
                  return CarListView(
                    cars: cars,
                    padding: EdgeInsets.fromLTRB(
                        16, comparing ? 8 : 16, 16, comparing ? 96 : 16),
                    header: comparing
                        ? Text(
                            'אפשר להשוות עד $maxCompareCars רכבים.',
                            style: context.text.caption,
                          )
                        : null,
                    cardBuilder: (car) => CarCard(
                      car: car,
                      saved: savedIds.contains(car.id),
                      priceDrop: drops[car.id],
                      selected: comparing
                          ? picked.any((c) => c.id == car.id)
                          : null,
                      onToggleSave: comparing
                          ? null
                          : () => ref
                              .read(toggleSavedProvider)
                              .call(car.id, false),
                      onTap: () {
                        if (!comparing) {
                          context.push('/car/${car.id}');
                          return;
                        }
                        final ok = ref
                            .read(compareSelectionProvider.notifier)
                            .toggle(car);
                        if (!ok) {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'אפשר להשוות עד $maxCompareCars רכבים — '
                                    'הסירו אחד כדי להוסיף אחר.'),
                              ),
                            );
                        }
                      },
                    ),
                  );
                },
              ),
      ),
      bottomNavigationBar:
          comparing && !isGuest ? _CompareBar(count: picked.length) : null,
    );
  }
}

/// The bar that appears while picking. It states the count rather than only
/// enabling a button, so "why is this greyed out" never comes up.
class _CompareBar extends ConsumerWidget {
  const _CompareBar({required this.count});

  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = count >= 2;

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Text(
                ready
                    ? 'נבחרו $count רכבים'
                    : 'נבחר $count מתוך 2 לפחות',
                style: ready ? AppText.subtitle : context.text.caption,
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: context.colors.tealFill),
              icon: const Icon(Icons.compare_arrows, size: 18),
              label: const Text('השווה'),
              onPressed: ready ? () => context.push('/compare') : null,
            ),
          ],
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
          SavedCheckIcon(size: 64, color: context.colors.textSubtle),
          const SizedBox(height: 12),
          Text('עדיין לא שמרת רכבים',
              style: TextStyle(color: context.colors.textMuted)),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.tealFill),
            onPressed: () => context.go('/home'),
            child: const Text('עבור לרכבים'),
          ),
        ],
      ),
    );
  }
}
