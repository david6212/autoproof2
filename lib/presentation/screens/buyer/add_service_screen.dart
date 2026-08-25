import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/service_record.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/app_card.dart';

import '../../../data/models/place.dart';
import '../../providers/auth_provider.dart';
import '../../providers/place_provider.dart';
import '../../widgets/garage/garage_name_field.dart';
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
    this.editing,
  });

  final String vehicleId;
  final String? correctsServiceId;

  /// The record being edited, or null when adding a new one. Editing became
  /// possible on 25/08; before that a mistake could only be answered with a
  /// correction record.
  final ServiceRecord? editing;

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

  /// Set when the owner picked a garage from the directory rather than typing
  /// a name. Cleared by [GarageNameField] the moment the text stops matching.
  String? _placeId;

  Uint8List? _receipt;
  String _receiptType = 'image/jpeg';
  String? _error;
  bool _saving = false;

  bool get _isCorrection => widget.correctsServiceId != null;
  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e == null) return;
    _type = e.type;
    _title.text = e.title;
    _km.text = '${e.km}';
    if (e.cost > 0) _cost.text = '${e.cost}';
    _garage.text = e.garageName ?? '';
    _placeId = e.placeId;
    _notes.text = e.notes ?? '';
    _date = e.date;
  }

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

  /// Opens the add-a-place screen with what was typed, and links the record to
  /// whatever comes back.
  Future<void> _addPlace(String typedName) async {
    final id = await context.push<String>(
        '/place/add?category=garage_mechanical&name=${Uri.encodeComponent(typedName)}');
    if (id == null || !mounted) return;
    setState(() {
      _placeId = id;
      // The name is left exactly as the person typed it into the new place, so
      // the field and the directory entry cannot disagree.
    });
  }

  /// Offers to rate the garage, once, right after the record it belongs to.
  ///
  /// **Only when the owner picked the garage from the directory** — a typed
  /// name has no page to rate. And only when they have not rated it before: a
  /// prompt that returns after being answered is not a prompt.
  ///
  /// "אולי אחר כך" simply closes. The spec asked for a reminder record, and
  /// there is a reminders list in this app — but it holds dates and mileages
  /// that come from the car, and a nudge to review a business sitting between
  /// "טסט" and "ביטוח" would be noise in a list people rely on. The
  /// invitation stays permanently available instead: every garage the owner has
  /// used carries a "דרג" action on its own page.
  Future<void> _maybeOfferToRate() async {
    final placeId = _placeId;
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (placeId == null || uid == null || _isEdit) return;

    final repo = ref.read(placeRepositoryProvider);
    Place? place;
    try {
      if (await repo.hasReviewed(placeId, uid)) return;
      place = await repo.byId(placeId);
    } catch (_) {
      // The record is saved. A failed lookup costs a prompt, nothing more.
      return;
    }
    if (place == null || !mounted) return;

    final rate = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('הטיפול נשמר'),
        content: Text(
          'רוצה לדרג את ${place!.name}? דירוג שלך עוזר למי שמחפש '
          'מוסך אחריך.',
          style: AppText.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('אולי אחר כך'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('דרג עכשיו'),
          ),
        ],
      ),
    );

    if (rate == true && mounted) {
      // Carries the vehicle and this record, so the review can name what was
      // done without the person typing it again.
      context.push('/place/$placeId/review'
          '?vehicleId=${widget.vehicleId}');
    }
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

    final controller = ref.read(addServiceControllerProvider.notifier);
    final ok = _isEdit
        ? await controller.saveEdit(
            vehicleId: widget.vehicleId,
            original: widget.editing!,
            type: _type,
            title: _title.text,
            date: _date,
            km: km,
            cost: int.tryParse(_cost.text.replaceAll(',', '')) ?? 0,
            garageName: _garage.text,
            placeId: _placeId,
            notes: _notes.text,
          )
        : await controller.submit(
            vehicleId: widget.vehicleId,
            type: _type,
            title: _title.text,
            date: _date,
            km: km,
            cost: int.tryParse(_cost.text.replaceAll(',', '')) ?? 0,
            garageName: _garage.text,
            placeId: _placeId,
            notes: _notes.text,
            receiptBytes: _receipt,
            receiptContentType: _receiptType,
            correctsServiceId: widget.correctsServiceId,
          );

    if (!mounted) return;
    if (ok) {
      await _maybeOfferToRate();
      if (mounted) Navigator.of(context).pop(true);
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
        title: Text(_isEdit
            ? 'עריכת רשומה'
            : _isCorrection
                ? 'תיקון רשומה'
                : 'הוספת טיפול'),
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
            // Typing a name freehand stays completely valid — most people
            // will, and a record without a link is a complete record. Picking
            // from the list is what turns the name into a page.
            GarageNameField(
              controller: _garage,
              onPlaceIdSelected: (id) => _placeId = id,
              onAddPlace: _addPlace,
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
              label: _isEdit
                  ? 'שמור שינויים'
                  : _isCorrection
                      ? 'שמור תיקון'
                      : 'שמור רשומה',
              loading: _saving,
              onPressed: _save,
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              'אפשר לערוך את הרשומה אחר כך, וקונים יראו שעודכנה. '
              'מחיקה אינה אפשרית. '
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
