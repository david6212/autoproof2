import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import '../../data/models/expense.dart';
import '../../data/repositories/expense_repository.dart';
import 'app_card.dart';

/// This month's spending, split by category.
///
/// Drawn with plain widgets rather than a charting package. A proportional bar
/// and a legend is all the shape this data has — six categories and one month —
/// and it did not seem worth a new dependency, a second layout system and an
/// extra 200 KB in the web bundle to draw a pie of six slices.
class ExpenseSummary extends StatelessWidget {
  const ExpenseSummary({super.key, required this.expenses});

  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final thisMonth =
        ExpenseRepository.inMonth(expenses, now.year, now.month);
    final total = thisMonth.fold<int>(0, (sum, e) => sum + e.amount);

    final byType = <ExpenseType, int>{};
    for (final e in thisMonth) {
      byType[e.type] = (byType[e.type] ?? 0) + e.amount;
    }
    final ordered = byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final consumption = ExpenseRepository.consumptionPer100Km(expenses);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('החודש', style: context.text.caption),
          const SizedBox(height: AppSpace.xs),
          Text('${_thousands(total)} ₪', style: AppText.display),
          if (ordered.isNotEmpty) ...[
            const SizedBox(height: AppSpace.lg),
            _Bar(segments: ordered, total: total),
            const SizedBox(height: AppSpace.md),
            for (final entry in ordered)
              _LegendRow(
                type: entry.key,
                amount: entry.value,
                color: colorFor(entry.key, context),
              ),
          ] else ...[
            const SizedBox(height: AppSpace.sm),
            Text('לא נרשמו הוצאות החודש', style: context.text.bodyMuted),
          ],
          if (consumption != null) ...[
            const Divider(height: AppSpace.xl),
            Row(
              children: [
                Icon(Icons.local_gas_station_outlined,
                    size: 18, color: context.colors.textMuted),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    'צריכה ממוצעת משוערת: '
                    '${consumption.toStringAsFixed(1)} ליטר ל-100 ק"מ',
                    style: AppText.bodySm,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xs),
            // Partial fills, a missed entry, a different driver — any of these
            // move the number. Saying "estimated" is the honest version.
            Text(
              'מחושב מהתדלוקים שרשמתם בהם ליטרים וק"מ.',
              style: context.text.caption,
            ),
          ],
        ],
      ),
    );
  }

  /// One colour per category, taken from the palette rather than invented, so
  /// the summary stays inside the app's colour system in both themes.
  static Color colorFor(ExpenseType type, BuildContext context) {
    final c = context.colors;
    return switch (type) {
      ExpenseType.fuel => c.teal,
      ExpenseType.cleaning => c.agentBlue,
      ExpenseType.parking => c.dealerOrange,
      ExpenseType.insurance => c.tealDark,
      ExpenseType.fees => c.warnText,
      ExpenseType.tolls => c.mintAccent,
      ExpenseType.other => c.textSubtle,
    };
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.segments, required this.total});

  final List<MapEntry<ExpenseType, int>> segments;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            for (final s in segments)
              Expanded(
                // Integer flex, so a category worth a rounding sliver still
                // gets a visible slice instead of collapsing to nothing.
                flex: (s.value * 1000 ~/ total).clamp(1, 1000),
                child: ColoredBox(
                  color: ExpenseSummary.colorFor(s.key, context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.type,
    required this.amount,
    required this.color,
  });

  final ExpenseType type;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Text(type.label, style: AppText.bodySm)),
          Text('${_thousands(amount)} ₪', style: AppText.bodySm),
        ],
      ),
    );
  }
}

String _thousands(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
