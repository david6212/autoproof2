import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_palette.dart';
import '../../../data/models/car_model.dart';
import '../../providers/cars_provider.dart';
import '../../../core/theme/app_text.dart';
import '../../widgets/app_card.dart';
import '../../widgets/share_listing_button.dart';
import '../../../core/theme/app_dimens.dart';
import '../../widgets/saved_check_icon.dart';

class MyListingScreen extends ConsumerWidget {
  const MyListingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingAsync = ref.watch(myActiveListingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('המודעה שלי')),
      body: SafeArea(
        child: listingAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Text('שגיאה בטעינה',
                style: TextStyle(color: context.colors.textMuted)),
          ),
          data: (car) => car == null ? const _Empty() : _Content(car: car),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.car});
  final CarModel car;

  static final _fmt = NumberFormat('#,###', 'en');

  int get _daysActive =>
      DateTime.now().difference(car.createdAt).inDays;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 160,
                child: car.coverPhoto == null
                    ? Container(
                        color: context.colors.tealLight,
                        child: Icon(Icons.directions_car,
                            size: 56, color: context.colors.teal))
                    : CachedNetworkImage(
                        imageUrl: car.coverPhoto!, fit: BoxFit.cover),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(car.title,
                          style: AppText.h3),
                    ),
                    Text('₪${_fmt.format(car.price)}',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.colors.tealText2)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const _Stat(
                icon: Icons.remove_red_eye_outlined,
                label: 'צפיות',
                value: '—'),
            _Stat(
                icon: Icons.check_rounded,
                iconWidget: SavedCheckIcon(
                    size: 20, color: context.colors.teal),
                label: 'מתעניינים',
                value: '—'),
            _Stat(
                icon: Icons.calendar_today_outlined,
                label: 'ימים פעילה',
                value: '$_daysActive'),
          ],
        ),
        const SizedBox(height: 24),
        Text('מי מתעניין ברכב שלך',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.all(20),
          radius: AppRadius.sm,
          child: Center(
            child: Text('כאן יופיעו קונים שמתעניינים ברכב שלך',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textMuted)),
          ),
        ),
        const SizedBox(height: 16),
        // The seller is the one with a reason to spread their own listing,
        // so this gets a full-width button rather than an icon.
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: context.colors.tealFill,
            minimumSize: const Size.fromHeight(48),
          ),
          icon: const Icon(Icons.ios_share),
          label: const Text('שתף את המודעה'),
          onPressed: () => shareListing(context, car),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: context.colors.tealText2,
            side: BorderSide(color: context.colors.teal),
            minimumSize: const Size.fromHeight(48),
          ),
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('הצ\'אטים שלי'),
          onPressed: () => context.go('/chats'),
        ),
        const SizedBox(height: 24),
        _SellerActions(carId: car.id),
      ],
    );
  }
}

/// Lets the seller mark the listing as sold or remove it. Both actions ask for
/// confirmation first, then flip the car's status (which drops it from the
/// active marketplace feed).
class _SellerActions extends ConsumerWidget {
  const _SellerActions({required this.carId});
  final String carId;

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ביטול'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: confirmColor),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _apply(
    BuildContext context,
    WidgetRef ref,
    CarStatus status,
    String snackText,
  ) async {
    await ref.read(updateListingStatusProvider).call(carId, status);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(snackText)));
    context.go('/seller');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: context.colors.tealFill,
            minimumSize: const Size.fromHeight(48),
          ),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('סמן כנמכר'),
          onPressed: () async {
            final ok = await _confirm(
              context,
              title: 'לסמן כנמכר?',
              body: 'המודעה תוסר מרשימת הרכבים הפעילים. אפשר לפרסם רכב חדש לאחר מכן.',
              confirmLabel: 'כן, נמכר',
              // The FILL token. `teal` is the identity green and carries white
              // at only 3.96:1 — under the floor for a button label, which is
              // the whole reason the two are separate tokens.
              confirmColor: context.colors.tealFill,
            );
            if (ok && context.mounted) {
              await _apply(context, ref, CarStatus.sold, 'מזל טוב! המודעה סומנה כנמכרה');
            }
          },
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: context.colors.errorRed),
          icon: const Icon(Icons.delete_outline),
          label: const Text('הסר מודעה'),
          onPressed: () async {
            final ok = await _confirm(
              context,
              title: 'להסיר את המודעה?',
              body: 'המודעה תוסר מהמערכת. פעולה זו אינה הפיכה.',
              confirmLabel: 'הסר',
              confirmColor: context.colors.errorRed,
            );
            if (ok && context.mounted) {
              await _apply(context, ref, CarStatus.removed, 'המודעה הוסרה');
            }
          },
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(
      {required this.icon,
      required this.label,
      required this.value,
      this.iconWidget});
  final IconData icon;

  /// Drawn instead of [icon] when the mark isn't a Material glyph.
  final Widget? iconWidget;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        margin: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
        padding: const EdgeInsets.symmetric(vertical: 14),
        radius: AppRadius.sm,
        child: Column(
          children: [
            iconWidget ?? Icon(icon, color: context.colors.teal, size: 20),
            const SizedBox(height: 4),
            Text(value,
                style: AppText.title),
            Text(label,
                style: TextStyle(
                    color: context.colors.textSubtle, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car_outlined,
              size: 64, color: context.colors.textSubtle),
          const SizedBox(height: 12),
          Text('אין לך מודעה פעילה',
              style: TextStyle(color: context.colors.textMuted)),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.tealFill),
            onPressed: () => context.go('/seller/create'),
            child: const Text('פרסם מודעה'),
          ),
        ],
      ),
    );
  }
}
