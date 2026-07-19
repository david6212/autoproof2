import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/inspector_model.dart';
import '../../providers/inspector_provider.dart';

class InspectorsScreen extends ConsumerWidget {
  const InspectorsScreen({super.key, required this.carId});

  final String carId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspectorsAsync = ref.watch(inspectorsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('בודקי רכב קרובים')),
      body: SafeArea(
        child: inspectorsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(
            child: Text('שגיאה בטעינת הבודקים',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          data: (list) {
            if (list.isEmpty) return const _Empty();
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, i) =>
                  _InspectorCard(inspector: list[i], carId: carId),
            );
          },
        ),
      ),
    );
  }
}

class _InspectorCard extends StatelessWidget {
  const _InspectorCard({required this.inspector, required this.carId});
  final InspectorModel inspector;
  final String carId;

  static final _fmt = NumberFormat('#,###', 'en');

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.tealLight,
                child: Icon(Icons.engineering, color: AppColors.teal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inspector.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.textPrimary)),
                    Text(inspector.certLevel,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 13)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 14, color: AppColors.starColor),
                        const SizedBox(width: 2),
                        Text('${inspector.rating}',
                            style: const TextStyle(fontSize: 12)),
                        Text(' (${inspector.reviewCount})',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSubtle)),
                        const SizedBox(width: 8),
                        Text('₪${_fmt.format(inspector.price)}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.teal)),
                      ],
                    ),
                  ],
                ),
              ),
              _AvailabilityBadge(available: inspector.available),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
              onPressed: () =>
                  context.push('/book/${inspector.id}?carId=$carId'),
              child: const Text('הזמן בדיקה'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  const _AvailabilityBadge({required this.available});
  final bool available;

  @override
  Widget build(BuildContext context) {
    final bg = available ? AppColors.tealLight : AppColors.warnBg;
    final fg = available ? AppColors.tealText2 : AppColors.warnText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        available ? 'פנוי עכשיו' : 'בעוד שעה',
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('אין בודקים זמינים כרגע',
          style: TextStyle(color: AppColors.textMuted)),
    );
  }
}
