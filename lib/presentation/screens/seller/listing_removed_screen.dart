import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';

class ListingRemovedScreen extends StatelessWidget {
  const ListingRemovedScreen({super.key});

  static const _reasons = [
    'התקבלו דיווחים חוזרים על אי-התאמה בין המודעה לרכב בפועל',
    'מודעות מדויקות שומרות על אמון הקונים בפלטפורמה',
    'ניתן להגיש ערעור אם אתה סבור שמדובר בטעות',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('המודעה הוסרה')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.errorBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppColors.errorRed, size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('המודעה הוסרה',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.errorRed)),
                          SizedBox(height: 2),
                          Text('בעקבות דיווחים חוזרים על אי-התאמה',
                              style: TextStyle(color: AppColors.errorRed)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              for (final r in _reasons)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.circle,
                          size: 8, color: AppColors.textSubtle),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(r,
                            style:
                                const TextStyle(color: AppColors.textMuted)),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: () {},
                child: const Text('להגיש ערעור'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/seller'),
                child: const Text('חזרה'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
