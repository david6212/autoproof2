import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/service_record.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button_widget.dart';

/// Adds one record to a vehicle's permanent history.
///
/// When [correctsServiceId] is set the screen is correcting an earlier entry
/// instead of adding a new event. That is the only way to fix a record: the
/// wrong one stays in the timeline, with the correction attached to it, so the
/// reader can see that something was corrected rather than finding a history
/// that quietly changed.
class AddServiceScreen extends ConsumerStatefulWidget {
  const AddServiceScreen({
    super.key,
    required this.vehicleId,
    this.correctsServiceId,
  });

  final String vehicleId;
  final String? correctsServiceId;

  @override
  ConsumerState<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends ConsumerState<AddServiceScreen> {
  ServiceType _type = ServiceType.routine;
  final _title = TextEditingController();
  final _km = TextEditingController();
  final _cost = TextEditingController();
  final _garage = TextEditingController();
  final _notes = TextEditingController();
  DateTime _date = DateTime.now();

  Uint8List? _receipt;
  String _receiptType = 'image/jpeg';
  String? _error;
  bool _saving = false;

  bool get _isCorrection => widget.correctsServiceId != null;

  @override
  void dispose() {
    _title.dispose();
    _km.dispose();
    _cost.dispose();
    _garage.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _receipt = bytes;
      _receiptType = 'image/jpeg';
    });
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
    final km = int.tryParse(_km.text.replaceAll(',', ''));
    if (km == null) {
      setState(() => _error = 'צריך למלא קילומטראז\'');
      return;
    }
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'צריך לתת שם לרשומה');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    final ok = await ref.read(addServiceControllerProvider.notifier).submit(
          vehicleId: widget.vehicleId,
          type: _type,
          title: _title.text,
          date: _date,
          km: km,
          cost: int.tryParse(_cost.text.replaceAll(',', '')) ?? 0,
          garageName: _garage.text,
          notes: _notes.text,
          receiptBytes: _receipt,
          receiptContentType: _receiptType,
          correctsServiceId: widget.correctsServiceId,
        );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }

    final err = ref.read(addServiceControllerProvider).error;
    setState(() {
      _saving = false;
      // The odometer rule speaks for itself, so show the repository's own
      // message rather than a generic failure.
      _error = err is ArgumentError
          ? '${err.message}'
          : 'לא הצלחנו לשמור את הרשומה. נסו שוב';
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isCorrection ? 'תיקון רשומה' : 'הוספת טיפול'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.lg),
          children: [
            if (_isCorrection) ...[
              Container(
                padding: const EdgeInsets.all(AppSpace.md),
                decoration: BoxDecoration(
                  color: colors.warnBg,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  'הרשומה המקורית תישאר בציר הזמן. התיקון יוצג לצידה.',
                  style: AppText.bodySm.copyWith(color: colors.warnText),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
            ],
            const Text('סוג', style: AppText.subtitle),
            const SizedBox(height: AppSpace.sm),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                for (final t in ServiceType.values)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.xl),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'מה נעשה',
                hintText: 'טיפול 60,000',
              ),
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
            const SizedBox(height: AppSpace.lg),
            TextField(
              controller: _km,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'קילומטראז\''),
            ),
            const SizedBox(height: AppSpace.lg),
            TextField(
              controller: _cost,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'עלות (₪)'),
            ),
            const SizedBox(height: AppSpace.lg),
            TextField(
              controller: _garage,
              decoration: const InputDecoration(
                labelText: 'שם המוסך (לא חובה)',
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'הערות (לא חובה)'),
            ),
            const SizedBox(height: AppSpace.xl),
            // No picker at all when Storage is not provisioned. Offering one
            // that always fails teaches people the feature is broken, and they
            // stop trusting the parts that work.
            if (AppConfig.storageEnabled)
              _ReceiptPicker(
                bytes: _receipt,
                onPick: _pickReceipt,
                onClear: () => setState(() => _receipt = null),
              )
            else
              Text(AppConfig.uploadsUnavailable, style: context.text.caption),
            if (_error != null) ...[
              const SizedBox(height: AppSpace.lg),
              Container(
                padding: const EdgeInsets.all(AppSpace.md),
                decoration: BoxDecoration(
                  color: colors.errorBg,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 18, color: colors.errorRed),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Text(
                        _error!,
                        style: AppText.bodySm.copyWith(color: colors.errorRed),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpace.xl),
            PrimaryButton(
              label: _isCorrection ? 'שמור תיקון' : 'שמור רשומה',
              loading: _saving,
              onPressed: _save,
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              'לאחר השמירה לא ניתן לערוך או למחוק את הרשומה. '
              'זה מה שהופך את התיק לאמין בעיני קונה.',
              style: context.text.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptPicker extends StatelessWidget {
  const _ReceiptPicker({
    required this.bytes,
    required this.onPick,
    required this.onClear,
  });

  final Uint8List? bytes;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (bytes == null) {
      return OutlinedButton.icon(
        onPressed: onPick,
        icon: const Icon(Icons.receipt_long_outlined),
        label: const Text('צרף קבלה'),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.sm),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: Image.memory(
              bytes!,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: AppSpace.md),
          const Expanded(child: Text('קבלה מצורפת', style: AppText.bodySm)),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'הסר',
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}
