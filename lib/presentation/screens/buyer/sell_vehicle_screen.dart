import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/car_model.dart';
import '../../../data/models/ownership_transfer.dart';
import '../../../data/models/vehicle.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button_widget.dart';

/// Closing a sale: the seller either hands the passport to a BonnetCheck buyer
/// or just takes the listing down.
///
/// The seller does the whole write, including marking the listing sold. The
/// buyer cannot touch someone else's listing, and a batch that contains one
/// refused write fails entirely — so putting it on the buyer's side would mean
/// the handover silently never completes.
class SellVehicleScreen extends ConsumerStatefulWidget {
  const SellVehicleScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<SellVehicleScreen> createState() => _SellVehicleScreenState();
}

class _SellVehicleScreenState extends ConsumerState<SellVehicleScreen> {
  String? _code;
  String? _error;
  bool _working = false;

  Future<void> _handOver(Vehicle vehicle) async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final gov = vehicle.govSnapshot ?? const {};
      final title = '${gov['make'] ?? ''} ${gov['model'] ?? ''}'.trim();
      final code = await ref.read(transferActionsProvider).createFor(
            vehicle,
            vehicleTitle: title,
          );
      if (mounted) setState(() => _code = code);
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            e is StateError ? e.message : 'לא הצלחנו ליצור קוד מסירה');
      }
    }
    if (mounted) setState(() => _working = false);
  }

  Future<void> _closeOnly(Vehicle vehicle) async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await ref
          .read(transferActionsProvider)
          .closeWithoutTransfer(vehicle, CarStatus.sold);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _working = false;
          _error = 'לא הצלחנו לעדכן את המודעה';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleAsync = ref.watch(vehicleProvider(widget.vehicleId));

    return Scaffold(
      appBar: AppBar(title: const Text('סימון כנמכר')),
      body: SafeArea(
        child: vehicleAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('לא הצלחנו לטעון את הרכב')),
          data: (vehicle) => vehicle == null
              ? const SizedBox.shrink()
              : _code != null
                  ? _CodeView(code: _code!, vehicle: vehicle)
                  : _choices(vehicle),
        ),
      ),
    );
  }

  Widget _choices(Vehicle vehicle) {
    return ListView(
      padding: const EdgeInsets.all(AppSpace.lg),
      children: [
        const Text('למי מכרתם את הרכב?', style: AppText.h3),
        const SizedBox(height: AppSpace.sm),
        Text(
          'אם הקונה משתמש ב-BonnetCheck, אפשר להעביר אליו את התיק — כל '
          'הטיפולים שתיעדתם יעברו איתו לרכב.',
          style: context.text.bodyMuted,
        ),
        const SizedBox(height: AppSpace.xl),
        AppCard(
          onTap: _working ? null : () => _handOver(vehicle),
          child: Row(
            children: [
              Icon(Icons.swap_horiz, color: context.colors.teal),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('לקונה שמשתמש באפליקציה',
                        style: AppText.subtitle),
                    Text(
                      'ניצור קוד מסירה שתמסרו לו. ${vehicle.serviceCount} '
                      'רשומות טיפול יעברו איתו.',
                      style: context.text.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),
        AppCard(
          onTap: _working || vehicle.activeCarId == null
              ? null
              : () => _closeOnly(vehicle),
          child: Row(
            children: [
              Icon(Icons.close, color: context.colors.textMuted),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('מכרתי מחוץ לאפליקציה',
                        style: AppText.subtitle),
                    Text(
                      'נסיר את המודעה. הרכב והתיק יישארו אצלכם.',
                      style: context.text.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpace.lg),
          Text(
            _error!,
            style: AppText.bodySm.copyWith(color: context.colors.errorRed),
          ),
        ],
        if (_working) ...[
          const SizedBox(height: AppSpace.xl),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }
}

class _CodeView extends StatelessWidget {
  const _CodeView({required this.code, required this.vehicle});

  final String code;
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListView(
      padding: const EdgeInsets.all(AppSpace.lg),
      children: [
        const Text('מסרו לקונה את הקוד', style: AppText.h3),
        const SizedBox(height: AppSpace.sm),
        Text(
          'הוא יזין אותו ב"הרכב שלי" והתיק יעבור אליו.',
          style: context.text.bodyMuted,
        ),
        const SizedBox(height: AppSpace.xl),
        AppCard(
          color: colors.tealLight,
          bordered: false,
          padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
          child: Column(
            children: [
              // LTR: a Latin code inside an RTL page reverses without this,
              // and a code read out backwards is a code that never works.
              Directionality(
                textDirection: TextDirection.ltr,
                child: SelectableText(
                  code,
                  style: AppText.display.copyWith(
                    fontSize: 40,
                    letterSpacing: 8,
                    color: colors.tealText,
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              TextButton.icon(
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('העתק'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('הקוד הועתק')),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        _Note(
          icon: Icons.schedule,
          text: 'הקוד תקף ${OwnershipTransfer.validFor.inDays} יום.',
        ),
        _Note(
          icon: Icons.history,
          text: vehicle.serviceCount == 1
              ? 'רשומת טיפול אחת תעבור לקונה.'
              : '${vehicle.serviceCount} רשומות טיפול יעברו לקונה.',
        ),
        const _Note(
          icon: Icons.lock_outline,
          text: 'ההוצאות שלכם והמסמכים הפרטיים לא עוברים.',
        ),
        const SizedBox(height: AppSpace.xl),
        PrimaryButton(label: 'סיימתי', onPressed: () => context.go('/garage')),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.md),
        child: Row(
          children: [
            Icon(icon, size: 18, color: context.colors.textMuted),
            const SizedBox(width: AppSpace.md),
            Expanded(child: Text(text, style: AppText.bodySm)),
          ],
        ),
      );
}
