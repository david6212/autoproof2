import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/inspector_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inspector_provider.dart';
import '../../widgets/primary_button_widget.dart';

class BookInspectionScreen extends ConsumerStatefulWidget {
  const BookInspectionScreen({
    super.key,
    required this.inspectorId,
    this.carId = '',
  });

  final String inspectorId;
  final String carId;

  @override
  ConsumerState<BookInspectionScreen> createState() =>
      _BookInspectionScreenState();
}

class _BookInspectionScreenState extends ConsumerState<BookInspectionScreen> {
  int _slot = 0;
  final Set<String> _topics = {'מנוע', 'גוף'};
  bool _booked = false;
  bool _booking = false;

  static const _slots = ['היום 17:00', 'מחר 10:00', 'מחר 15:00'];
  static const _topicOptions = [
    'מנוע', 'גוף', 'בלמים', 'מיזוג', 'חשמל', 'גלגלים',
  ];
  static final _fmt = NumberFormat('#,###', 'en');

  void selectSlot(int i) => setState(() => _slot = i);

  void toggleTopic(String t, bool sel) => setState(() {
        if (sel) {
          _topics.add(t);
        } else {
          _topics.remove(t);
        }
      });

  Future<void> _confirm(InspectorModel inspector) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    setState(() => _booking = true);
    try {
      await ref.read(inspectorRepositoryProvider).createBooking(
            inspectorId: inspector.id,
            carId: widget.carId,
            buyerId: user.uid,
            topics: _topics.toList(),
            amount: inspector.price,
          );
      setState(() => _booked = true);
    } catch (_) {
      setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inspectorAsync = ref.watch(inspectorByIdProvider(widget.inspectorId));

    return Scaffold(
      appBar: AppBar(title: const Text('הזמנת בדיקה')),
      body: SafeArea(
        child: inspectorAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(
            child: Text('שגיאה בטעינה',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          data: (inspector) {
            if (inspector == null) {
              return const Center(child: Text('הבודק לא נמצא'));
            }
            if (_booked) return _Success(inspector: inspector);
            return _Form(inspector: inspector, state: this);
          },
        ),
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({required this.inspector, required this.state});
  final InspectorModel inspector;
  final _BookInspectionScreenState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _summary(inspector),
                const SizedBox(height: 20),
                const _Label('בחר מועד'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 0; i < _BookInspectionScreenState._slots.length; i++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(left: i == 2 ? 0 : 8),
                          child: _SlotChip(
                            label: _BookInspectionScreenState._slots[i],
                            selected: state._slot == i,
                            onTap: () => state.selectSlot(i),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                const _Label('נושאים לבדיקה'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in _BookInspectionScreenState._topicOptions)
                      FilterChip(
                        label: Text(t),
                        selected: state._topics.contains(t),
                        showCheckmark: false,
                        selectedColor: AppColors.teal,
                        backgroundColor: AppColors.white,
                        labelStyle: TextStyle(
                          color: state._topics.contains(t)
                              ? AppColors.white
                              : AppColors.textMuted,
                        ),
                        onSelected: (sel) => state.toggleTopic(t, sel),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                _priceSummary(inspector),
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
                label:
                    'אשר הזמנה · ₪${_BookInspectionScreenState._fmt.format(inspector.price)}',
                loading: state._booking,
                onPressed: () => state._confirm(inspector),
              ),
              const SizedBox(height: 6),
              const Text('התשלום יתבצע רק לאחר הבדיקה',
                  style: TextStyle(color: AppColors.textSubtle, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summary(InspectorModel i) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tealLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.teal,
            child: Icon(Icons.engineering, color: AppColors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.tealText)),
                Text(i.certLevel,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.tealText2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceSummary(InspectorModel i) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          _row('בדיקה', '₪${_BookInspectionScreenState._fmt.format(i.price)}'),
          _row('נסיעה', 'חינם'),
          const Divider(),
          _row('סה"כ', '₪${_BookInspectionScreenState._fmt.format(i.price)}',
              bold: true),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: bold ? AppColors.textPrimary : AppColors.textMuted,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontWeight: FontWeight.bold, color: AppColors.textPrimary));
}

class _SlotChip extends StatelessWidget {
  const _SlotChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.teal : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppColors.teal : AppColors.cardBorder),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                color: selected ? AppColors.white : AppColors.textMuted)),
      ),
    );
  }
}

class _Success extends StatelessWidget {
  const _Success({required this.inspector});
  final InspectorModel inspector;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: AppColors.tealLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, size: 56, color: AppColors.teal),
          ),
          const SizedBox(height: 20),
          const Text('הבדיקה הוזמנה!',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text('${inspector.name} יצור איתך קשר לתיאום סופי',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'חזרה',
              onPressed: () => context.pop(),
            ),
          ),
        ],
      ),
    );
  }
}
