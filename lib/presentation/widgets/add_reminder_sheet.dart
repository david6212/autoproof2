import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text.dart';
import '../../data/models/vehicle_reminder.dart';
import '../providers/vehicle_provider.dart';
import 'primary_button_widget.dart';

/// Adds a reminder the owner sets themselves.
///
/// Only the test date is ever created automatically, because it is the one
/// date the vehicle registry actually publishes. Everything else — the timing
/// belt, the insurance renewal, a service due at a mileage — is the owner's to
/// enter. Shipping a table of "recommended" intervals would mean the app
/// asserting something about their particular car that we have no source for.
class AddReminderSheet extends ConsumerStatefulWidget {
  const AddReminderSheet({super.key, required this.vehicleId});

  final String vehicleId;

  static Future<void> show(BuildContext context, String vehicleId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddReminderSheet(vehicleId: vehicleId),
      ),
    );
  }

  @override
  ConsumerState<AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends ConsumerState<AddReminderSheet> {
  ReminderType _type = ReminderType.timingBelt;
  final _title = TextEditingController();
  final _km = TextEditingController();
  DateTime? _date;
  bool _saving = false;

  /// Mileage reminders make no sense as a date, and vice versa. The sheet
  /// switches rather than showing both and letting the owner fill in nothing.
  bool get _byKm => _type == ReminderType.serviceKm;

  @override
  void dispose() {
    _title.dispose();
    _km.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 30)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 10)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_byKm && _date == null) return;
    if (_byKm && int.tryParse(_km.text) == null) return;

    setState(() => _saving = true);
    await ref.read(vehicleRepositoryProvider).addReminder(
          widget.vehicleId,
          VehicleReminder(
            id: '',
            type: _type,
            title: _title.text.trim().isEmpty ? _type.label : _title.text.trim(),
            dueDate: _byKm ? null : _date,
            dueKm: _byKm ? int.tryParse(_km.text.replaceAll(',', '')) : null,
            createdAt: DateTime.now(),
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // The test reminder is created from official data, so it is not offered
    // here — two reminders for the same date would just be noise.
    final offered = [
      for (final t in ReminderType.values)
        if (t != ReminderType.test) t,
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('תזכורת חדשה', style: AppText.h3),
            const SizedBox(height: AppSpace.lg),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                for (final t in offered)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            TextField(
              controller: _title,
              decoration: InputDecoration(
                labelText: 'שם התזכורת',
                hintText: _type.label,
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            if (_byKm)
              TextField(
                controller: _km,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'להזכיר בקילומטראז\'',
                  hintText: '100000',
                ),
              )
            else
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'תאריך'),
                  child: Text(
                    _date == null
                        ? 'בחרו תאריך'
                        : '${_date!.day}/${_date!.month}/${_date!.year}',
                    style: _date == null
                        ? context.text.bodyMuted
                        : AppText.body,
                  ),
                ),
              ),
            const SizedBox(height: AppSpace.xl),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: 'שמור תזכורת',
                loading: _saving,
                onPressed: _save,
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              'התזכורות מוצגות באפליקציה כשפותחים אותה. אין כרגע התראות דחיפה.',
              style: context.text.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
