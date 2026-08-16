import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/gov_data_model.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button_widget.dart';
import '../../widgets/spec_tile.dart';

/// Plate → official record → confirm → passport.
///
/// The plate is all we ask for. Everything else about the car comes from the
/// vehicle registry we already query for listings, so the owner is confirming
/// what the state says rather than typing out their own car.
class AddVehicleScreen extends ConsumerStatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  ConsumerState<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends ConsumerState<AddVehicleScreen> {
  final _plate = TextEditingController();
  final _nickname = TextEditingController();
  final _km = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _plate.dispose();
    _nickname.dispose();
    _km.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    await ref.read(addVehicleControllerProvider.notifier).lookup(_plate.text);
    if (mounted) setState(() => _searching = false);

    // The registry's last-test reading is the best starting odometer we have,
    // and it saves the owner walking out to the car to read the dash.
    final found = ref.read(addVehicleControllerProvider).found;
    final testKm = found?.lastTestKm;
    if (testKm != null && _km.text.isEmpty) _km.text = '$testKm';
  }

  Future<void> _save() async {
    final id = await ref.read(addVehicleControllerProvider.notifier).save(
          nickname: _nickname.text,
          currentKm: int.tryParse(_km.text.replaceAll(',', '')) ?? 0,
        );
    if (!mounted || id == null) return;
    context.pushReplacement('/vehicle/$id');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addVehicleControllerProvider);
    final found = state.found;

    return Scaffold(
      appBar: AppBar(title: const Text('הוספת רכב')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.lg),
          children: [
            if (found == null) ..._plateStep(state) else ..._confirmStep(found),
          ],
        ),
      ),
    );
  }

  List<Widget> _plateStep(AddVehicleState state) {
    return [
      const Text('מה מספר הרישוי?', style: AppText.h3),
      const SizedBox(height: AppSpace.sm),
      Text(
        'נמשוך את פרטי הרכב ממשרד התחבורה כדי שלא תצטרכו להקליד אותם.',
        style: context.text.bodyMuted,
      ),
      const SizedBox(height: AppSpace.xl),
      TextField(
        controller: _plate,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textDirection: TextDirection.ltr,
        decoration: const InputDecoration(
          labelText: 'מספר רישוי',
          hintText: '12345678',
        ),
        onSubmitted: (_) => _search(),
      ),
      if (state.error != null) ...[
        const SizedBox(height: AppSpace.md),
        _ErrorNote(
          message: state.error!,
          action: state.alreadyOwned == null
              ? null
              : _OwnedAction(vehicleId: state.alreadyOwned!.id),
        ),
      ],
      const SizedBox(height: AppSpace.xl),
      PrimaryButton(
        label: 'חפש רכב',
        loading: _searching,
        onPressed: _search,
      ),
    ];
  }

  List<Widget> _confirmStep(GovData car) {
    final state = ref.watch(addVehicleControllerProvider);
    final saving = state.step == AddVehicleStep.saving;
    final name =
        car.commercialName.isNotEmpty ? car.commercialName : car.model;

    return [
      const Text('זה הרכב שלכם?', style: AppText.h3),
      const SizedBox(height: AppSpace.lg),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${car.make} $name'.trim(), style: AppText.title),
            const SizedBox(height: AppSpace.xs),
            Text('${car.year} · ${car.plate}', style: context.text.caption),
            const SizedBox(height: AppSpace.lg),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                if (car.fuelType.isNotEmpty)
                  SizedBox(
                    width: 150,
                    child: SpecTile(
                      icon: Icons.local_gas_station_outlined,
                      label: 'סוג דלק',
                      value: car.fuelType,
                    ),
                  ),
                if (car.color.isNotEmpty)
                  SizedBox(
                    width: 150,
                    child: SpecTile(
                      icon: Icons.palette_outlined,
                      label: 'צבע',
                      value: car.color,
                    ),
                  ),
                if (car.licenseExpiry != null)
                  SizedBox(
                    width: 150,
                    child: SpecTile(
                      icon: Icons.event_available_outlined,
                      label: 'תוקף טסט',
                      value: car.licenseExpiryDisplay,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpace.xl),
      TextField(
        controller: _nickname,
        decoration: const InputDecoration(
          labelText: 'כינוי לרכב (לא חובה)',
          hintText: 'האוטו של אמא',
        ),
      ),
      const SizedBox(height: AppSpace.lg),
      TextField(
        controller: _km,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: 'קילומטראז\' נוכחי',
          helperText: 'הושלם מהטסט האחרון — עדכנו אם הרכב נסע מאז',
        ),
      ),
      if (state.error != null) ...[
        const SizedBox(height: AppSpace.md),
        _ErrorNote(message: state.error!),
      ],
      const SizedBox(height: AppSpace.xl),
      PrimaryButton(
        label: 'הוסף לרכבים שלי',
        loading: saving,
        onPressed: _save,
      ),
      const SizedBox(height: AppSpace.sm),
      TextButton(
        onPressed: saving
            ? null
            : () => ref.read(addVehicleControllerProvider.notifier).back(),
        child: const Text('זה לא הרכב שלי'),
      ),
    ];
  }
}

class _OwnedAction extends StatelessWidget {
  const _OwnedAction({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: () => context.pushReplacement('/vehicle/$vehicleId'),
        child: const Text('פתח את הרכב'),
      );
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: colors.errorBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, size: 18, color: colors.errorRed),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  message,
                  style: AppText.bodySm.copyWith(color: colors.errorRed),
                ),
              ),
            ],
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
