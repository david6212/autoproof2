import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../providers/swipe_provider.dart';
import '../../widgets/primary_button_widget.dart';

class SwipePrefsScreen extends ConsumerStatefulWidget {
  const SwipePrefsScreen({super.key});

  @override
  ConsumerState<SwipePrefsScreen> createState() => _SwipePrefsScreenState();
}

class _SwipePrefsScreenState extends ConsumerState<SwipePrefsScreen> {
  double _budget = 150000;
  int _minYear = 2015;
  final Set<String> _types = {};

  static const _typeOptions = [
    'משפחתי', 'קרוסאובר', 'היברידי', 'חשמלי', 'ספורט', 'מיני',
  ];

  static final _fmt = NumberFormat('#,###', 'en');

  void _start() {
    ref.read(swipePrefsProvider.notifier).state = SwipePrefs(
      maxBudget: _budget,
      types: _types,
      minYear: _minYear,
    );
    // Reset the swiped-set so candidates are fresh.
    ref.read(processedIdsProvider.notifier).state = {};
    context.push('/swipe');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('גילוי')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'מה אתה מחפש?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),

              // Budget
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('תקציב מקסימלי',
                      style: TextStyle(color: AppColors.textMuted)),
                  Text('₪${_fmt.format(_budget)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.teal)),
                ],
              ),
              Slider(
                value: _budget,
                min: 30000,
                max: 500000,
                divisions: 47,
                activeColor: AppColors.teal,
                onChanged: (v) => setState(() => _budget = v),
              ),
              const SizedBox(height: 16),

              // Types
              const Text('סוג רכב',
                  style: TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in _typeOptions)
                    FilterChip(
                      label: Text(t),
                      selected: _types.contains(t),
                      showCheckmark: false,
                      selectedColor: AppColors.teal,
                      backgroundColor: AppColors.white,
                      labelStyle: TextStyle(
                        color: _types.contains(t)
                            ? AppColors.white
                            : AppColors.textMuted,
                      ),
                      onSelected: (sel) => setState(() {
                        if (sel) {
                          _types.add(t);
                        } else {
                          _types.remove(t);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Min year
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('שנת ייצור מינימלית',
                      style: TextStyle(color: AppColors.textMuted)),
                  Text('$_minYear',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.teal)),
                ],
              ),
              Slider(
                value: _minYear.toDouble(),
                min: 2005,
                max: 2025,
                divisions: 20,
                activeColor: AppColors.teal,
                onChanged: (v) => setState(() => _minYear = v.round()),
              ),

              const Spacer(),
              PrimaryButton(
                label: 'התחל לגלות רכבים',
                onPressed: _start,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
