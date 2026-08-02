import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// A "step X / total" progress bar for the verification flow.
class StepProgress extends StatelessWidget {
  const StepProgress({
    super.key,
    required this.current,
    this.total = 3,
  });

  final int current; // 1-based
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: List.generate(total, (i) {
            final done = i < current;
            return Expanded(
              child: Container(
                height: 6,
                margin: EdgeInsets.only(left: i == total - 1 ? 0 : 6),
                decoration: BoxDecoration(
                  color: done ? context.colors.teal : context.colors.cardBorder,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          'שלב $current מתוך $total',
          style: TextStyle(color: context.colors.textMuted, fontSize: 13),
        ),
      ],
    );
  }
}
