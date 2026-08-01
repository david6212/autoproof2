import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/car_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cars_provider.dart';
import '../../../core/theme/app_text.dart';

class SellerHomeScreen extends ConsumerWidget {
  const SellerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserModelProvider).valueOrNull;
    final listingAsync = ref.watch(myActiveListingProvider);
    final name = (user?.name.isNotEmpty ?? false) ? user!.name : 'מוכר';

    return Scaffold(
      appBar: AppBar(title: const Text('מרכז המוכר')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('שלום, $name',
                style: AppText.h1),
            const SizedBox(height: 16),
            listingAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
              data: (car) => car == null
                  ? _NoListing()
                  : _ActiveListingCard(car: car),
            ),
            const SizedBox(height: 24),
            const Text('טיפים למכירה מהירה',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const _Tip(
              icon: Icons.photo_camera_outlined,
              text: 'העלה לפחות 6 תמונות באור יום — מודעות עם תמונות נצפות פי 3.',
            ),
            const _Tip(
              icon: Icons.bolt_outlined,
              text: 'הגב להודעות תוך שעה כדי לא לאבד קונים מתעניינים.',
            ),
          ],
        ),
      ),
    );
  }
}

class _NoListing extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.tealLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.add_road, size: 40, color: AppColors.teal),
          const SizedBox(height: 8),
          const Text('אין לך מודעה פעילה',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.tealText)),
          const SizedBox(height: 4),
          const Text('פרסם את הרכב שלך ותתחיל לקבל פניות',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.tealText2, fontSize: 13)),
          const SizedBox(height: 12),
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

class _ActiveListingCard extends StatelessWidget {
  const _ActiveListingCard({required this.car});
  final CarModel car;

  static final _fmt = NumberFormat('#,###', 'en');

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/seller/listing'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 110,
              height: 90,
              child: car.coverPhoto == null
                  ? Container(
                      color: AppColors.tealLight,
                      child: const Icon(Icons.directions_car,
                          color: AppColors.teal))
                  : CachedNetworkImage(
                      imageUrl: car.coverPhoto!, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('המודעה הפעילה שלך',
                      style: TextStyle(
                          fontSize: 12.5, color: AppColors.textSubtle)),
                  const SizedBox(height: 2),
                  Text(car.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  Text('₪${_fmt.format(car.price)}',
                      style: const TextStyle(color: AppColors.teal)),
                ],
              ),
            ),
            const Icon(Icons.chevron_left, color: AppColors.textSubtle),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.teal, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
