import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/car_model.dart';
import '../../providers/cars_provider.dart';

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
          error: (_, __) => const Center(
            child: Text('שגיאה בטעינה',
                style: TextStyle(color: AppColors.textMuted)),
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
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 160,
                child: car.coverPhoto == null
                    ? Container(
                        color: AppColors.tealLight,
                        child: const Icon(Icons.directions_car,
                            size: 56, color: AppColors.teal))
                    : CachedNetworkImage(
                        imageUrl: car.coverPhoto!, fit: BoxFit.cover),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(car.title,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                    ),
                    Text('₪${_fmt.format(car.price)}',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.teal)),
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
            const _Stat(
                icon: Icons.favorite_border,
                label: 'מתעניינים',
                value: '—'),
            _Stat(
                icon: Icons.calendar_today_outlined,
                label: 'ימים פעילה',
                value: '$_daysActive'),
          ],
        ),
        const SizedBox(height: 24),
        const Text('מי מתעניין ברכב שלך',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: const Center(
            child: Text('כאן יופיעו קונים שמתעניינים ברכב שלך',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted)),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.teal,
            side: const BorderSide(color: AppColors.teal),
            minimumSize: const Size.fromHeight(48),
          ),
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('הצ\'אטים שלי'),
          onPressed: () => context.go('/chats'),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.teal, size: 20),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary)),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSubtle, fontSize: 12)),
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
          const Icon(Icons.directions_car_outlined,
              size: 64, color: AppColors.textSubtle),
          const SizedBox(height: 12),
          const Text('אין לך מודעה פעילה',
              style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
            onPressed: () => context.go('/seller/create'),
            child: const Text('פרסם מודעה'),
          ),
        ],
      ),
    );
  }
}
