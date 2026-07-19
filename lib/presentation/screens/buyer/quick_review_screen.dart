import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cars_provider.dart';
import '../../widgets/primary_button_widget.dart';

/// Anonymous "help a future buyer" review. IMPORTANT: reviews are stored
/// WITHOUT a sellerId, so the seller can never see or query them.
class QuickReviewScreen extends ConsumerStatefulWidget {
  const QuickReviewScreen({super.key, required this.carId});

  final String carId;

  @override
  ConsumerState<QuickReviewScreen> createState() => _QuickReviewScreenState();
}

class _QuickReviewScreenState extends ConsumerState<QuickReviewScreen> {
  final _text = TextEditingController();
  final Set<String> _reasons = {};
  bool _anonymous = true;
  bool _sending = false;

  static const _reasonOptions = ['הטריד אותי', 'מצאתי אחר', 'המחיר', 'מצב הרכב'];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    setState(() => _sending = true);
    try {
      // NOTE: no sellerId field — the seller can never see this review.
      await ref.read(reviewWriteProvider).call(
            carId: widget.carId,
            reviewerId: _anonymous ? '' : user.uid,
            anonymous: _anonymous,
            reasons: _reasons.toList(),
            text: _text.text.trim(),
          );
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('עזרה לקונה')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'עזרה למישהו שעומד לראות רכב',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.tealLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'אתה לא חייב לקנות כדי לעזור. חוות הדעת אנונימית — המוכר לא רואה אותה.',
                        style: TextStyle(
                            color: AppColors.tealText2, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('למה לא קנית?',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final r in _reasonOptions)
                          FilterChip(
                            label: Text(r),
                            selected: _reasons.contains(r),
                            showCheckmark: false,
                            selectedColor: AppColors.teal,
                            backgroundColor: AppColors.white,
                            labelStyle: TextStyle(
                              color: _reasons.contains(r)
                                  ? AppColors.white
                                  : AppColors.textMuted,
                            ),
                            onSelected: (sel) => setState(() {
                              if (sel) {
                                _reasons.add(r);
                              } else {
                                _reasons.remove(r);
                              }
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _text,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'מה כדאי שידע?',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: _anonymous,
                      activeColor: AppColors.teal,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('שלח באופן אנונימי'),
                      onChanged: (v) => setState(() => _anonymous = v),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.white,
                border: Border(top: BorderSide(color: AppColors.cardBorder)),
              ),
              child: Column(
                children: [
                  PrimaryButton(
                    label: 'שלח עזרה',
                    loading: _sending,
                    onPressed: _send,
                  ),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('דלג'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
