import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import '../../data/models/fuel_report.dart';
import '../../data/models/fuel_station.dart';
import '../providers/auth_provider.dart';
import '../providers/fuel_report_provider.dart';
import 'login_required_sheet.dart';

/// Asks the driver what diesel cost at a station, and stores it as their one
/// report for that station.
///
/// Guarded twice, and neither guard is redundant: the field's own validation
/// catches a typo before a round trip, and the Firestore rules reject the same
/// range server-side so nobody can post 0.01 ₪ to make a station look cheap.
Future<void> showFuelReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required FuelStation station,
  int? current,
}) async {
  final uid = ref.read(authStateProvider).valueOrNull?.uid;
  if (uid == null) {
    showLoginRequired(context, action: 'לדווח על מחיר סולר');
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _Sheet(station: station, uid: uid, current: current),
  );
}

class _Sheet extends ConsumerStatefulWidget {
  const _Sheet({required this.station, required this.uid, this.current});

  final FuelStation station;
  final String uid;
  final int? current;

  @override
  ConsumerState<_Sheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<_Sheet> {
  late final _controller = TextEditingController(
    text: widget.current == null
        ? ''
        : (widget.current! / 100).toStringAsFixed(2),
  );
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Accepts "7.29" and "7,29" — a comma is what a numeric keypad offers in
  /// some locales, and rejecting it would look like the app is broken.
  int? _parse(String raw) {
    final cleaned = raw.trim().replaceAll(',', '.');
    final shekels = double.tryParse(cleaned);
    if (shekels == null) return null;
    return (shekels * 100).round();
  }

  Future<void> _submit() async {
    final agorot = _parse(_controller.text);
    if (agorot == null) {
      setState(() => _error = 'הזינו מחיר, למשל 7.29');
      return;
    }
    if (!FuelReport.isPlausible(agorot)) {
      setState(() => _error =
          'מחיר לליטר בין ${FuelReport.minAgorot ~/ 100} ל-${FuelReport.maxAgorot ~/ 100} ₪');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(fuelReportRepositoryProvider).report(
            stationId: widget.station.id,
            uid: widget.uid,
            agorot: agorot,
          );
      ref.invalidate(fuelMediansProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'לא הצלחנו לשמור את הדיווח. נסו שוב.';
        });
      }
    }
  }

  Future<void> _remove() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(fuelReportRepositoryProvider)
          .remove(stationId: widget.station.id, uid: widget.uid);
      ref.invalidate(fuelMediansProvider);
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl)),
        ),
        padding: const EdgeInsets.fromLTRB(
            AppSpace.xl, AppSpace.md, AppSpace.xl, AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.cardBorder,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            const Text('דיווח מחיר סולר', style: AppText.h3),
            const SizedBox(height: 2),
            Text(widget.station.displayName,
                style: context.text.bodySmMuted),
            const SizedBox(height: AppSpace.lg),
            TextField(
              controller: _controller,
              autofocus: true,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              style: AppText.h2,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                LengthLimitingTextInputFormatter(5),
              ],
              decoration: InputDecoration(
                hintText: '7.29',
                suffixText: '₪ לליטר',
                errorText: _error,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              'דווחו את המחיר שראיתם על השילוט בתחנה. הדיווח שלכם מוצג לנהגים '
              'אחרים יחד עם מועד הדיווח, ואפשר לעדכן או למחוק אותו בכל רגע.',
              style: context.text.captionSubtle,
            ),
            const SizedBox(height: AppSpace.lg),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving
                  ? 'שומר…'
                  : widget.current == null
                      ? 'שלח דיווח'
                      : 'עדכן דיווח'),
            ),
            if (widget.current != null) ...[
              const SizedBox(height: AppSpace.sm),
              TextButton(
                onPressed: _saving ? null : _remove,
                child: Text('מחק את הדיווח שלי',
                    style: TextStyle(color: context.colors.errorRed)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
