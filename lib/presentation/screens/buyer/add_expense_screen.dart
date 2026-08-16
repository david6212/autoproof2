import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/expense.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/primary_button_widget.dart';

/// Logs a running cost, or fixes one already logged.
///
/// Editing is allowed here and refused for service records, which looks
/// inconsistent until you remember who each ledger is for: a service record is
/// evidence shown to a stranger, an expense is the owner's own note to self. A
/// mistyped refuel should cost one tap to fix, not a correction record.
class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({
    super.key,
    required this.vehicleId,
    this.existing,
  });

  final String vehicleId;

  /// Set when editing rather than adding.
  final Expense? existing;

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  late ExpenseType _type = widget.existing?.type ?? ExpenseType.fuel;
  late final _amount =
      TextEditingController(text: widget.existing?.amount.toString() ?? '');
  late final _litres = TextEditingController(
      text: widget.existing?.litres?.toStringAsFixed(2) ?? '');
  late final _km =
      TextEditingController(text: widget.existing?.km?.toString() ?? '');
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late DateTime _date = widget.existing?.date ?? DateTime.now();

  String? _error;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;
  bool get _isFuel => _type == ExpenseType.fuel;

  @override
  void dispose() {
    _amount.dispose();
    _litres.dispose();
    _km.dispose();
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final amount = int.tryParse(_amount.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'צריך למלא סכום');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    final expense = Expense(
      id: widget.existing?.id ?? '',
      type: _type,
      title: _title.text,
      date: _date,
      amount: amount,
      litres: _isFuel ? double.tryParse(_litres.text) : null,
      km: _isFuel ? int.tryParse(_km.text.replaceAll(',', '')) : null,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    try {
      final actions = ref.read(expenseActionsProvider);
      if (_isEdit) {
        await actions.update(widget.vehicleId, expense);
      } else {
        await actions.add(widget.vehicleId, expense);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'לא הצלחנו לשמור. נסו שוב';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'עריכת הוצאה' : 'הוספת הוצאה')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.lg),
          children: [
            const Text('סוג', style: AppText.subtitle),
            const SizedBox(height: AppSpace.sm),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                for (final t in ExpenseType.values)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.xl),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'סכום (₪)'),
            ),
            const SizedBox(height: AppSpace.lg),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'תאריך'),
                child: Text(
                  '${_date.day}/${_date.month}/${_date.year}',
                  style: AppText.body,
                ),
              ),
            ),
            if (_isFuel) ...[
              const SizedBox(height: AppSpace.lg),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _litres,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'ליטרים'),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: TextField(
                      controller: _km,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'ק"מ במד'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                'שני השדות לא חובה — אבל אם תמלאו אותם בכל תדלוק, נוכל לחשב '
                'את הצריכה האמיתית של הרכב.',
                style: context.text.caption,
              ),
            ],
            const SizedBox(height: AppSpace.lg),
            TextField(
              controller: _title,
              decoration: InputDecoration(
                labelText: 'תיאור (לא חובה)',
                hintText: _isFuel ? 'תחנת דלק' : _type.label,
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'הערות (לא חובה)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpace.lg),
              Container(
                padding: const EdgeInsets.all(AppSpace.md),
                decoration: BoxDecoration(
                  color: colors.errorBg,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  _error!,
                  style: AppText.bodySm.copyWith(color: colors.errorRed),
                ),
              ),
            ],
            const SizedBox(height: AppSpace.xl),
            PrimaryButton(
              label: _isEdit ? 'שמור שינויים' : 'שמור',
              loading: _saving,
              onPressed: _save,
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              'ההוצאות שלכם פרטיות. הן לא מוצגות לקונים, גם לא כשהרכב מפורסם '
              'למכירה.',
              style: context.text.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
