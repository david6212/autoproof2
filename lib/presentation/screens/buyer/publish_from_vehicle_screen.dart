import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/car_model.dart';
import '../../../data/models/vehicle.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cars_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/primary_button_widget.dart';
import '../../widgets/service_timeline.dart';

/// Publishing a car straight out of its passport.
///
/// This is where the loop closes. Everything the ordinary create-listing flow
/// asks the seller to type is already known — the registry data, the odometer,
/// the history — so all that is left is a price and why they are selling. The
/// service timeline goes with it, which is the payoff for years of logging and
/// the reason a documented car is worth more than an undocumented one.
class PublishFromVehicleScreen extends ConsumerStatefulWidget {
  const PublishFromVehicleScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<PublishFromVehicleScreen> createState() =>
      _PublishFromVehicleScreenState();
}

class _PublishFromVehicleScreenState
    extends ConsumerState<PublishFromVehicleScreen> {
  final _price = TextEditingController();
  final _area = TextEditingController();
  final _reason = TextEditingController();
  final _description = TextEditingController();

  String? _error;
  bool _publishing = false;

  @override
  void dispose() {
    _price.dispose();
    _area.dispose();
    _reason.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _publish(Vehicle vehicle) async {
    final price = double.tryParse(_price.text.replaceAll(',', ''));
    if (price == null || price <= 0) {
      setState(() => _error = 'צריך למלא מחיר');
      return;
    }
    if (_area.text.trim().isEmpty) {
      setState(() => _error = 'צריך למלא אזור');
      return;
    }

    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    setState(() {
      _error = null;
      _publishing = true;
    });

    final gov = vehicle.govSnapshot ?? const {};
    final year = gov['year'];

    final car = CarModel(
      id: '',
      plate: vehicle.plate,
      make: '${gov['make'] ?? ''}',
      model: '${gov['model'] ?? ''}',
      year: year is int ? year : int.tryParse('$year') ?? 0,
      price: price,
      km: vehicle.currentKm,
      hand: 1,
      area: _area.text.trim(),
      sellerId: uid,
      status: CarStatus.active,
      govData: {
        'fuelType': gov['fuelType'] ?? '',
        'color': gov['color'] ?? '',
        'ownershipType': gov['ownershipType'] ?? '',
      },
      fuel: '${gov['fuelType'] ?? ''}',
      color: '${gov['color'] ?? ''}',
      ownership: '${gov['ownershipType'] ?? ''}',
      photos: const [],
      reasonForSelling: _reason.text.trim(),
      description: _description.text.trim(),
      createdAt: DateTime.now(),
      vehicleId: vehicle.id,
      hasDocumentedHistory: vehicle.hasDocumentedHistory,
      serviceCount: vehicle.serviceCount,
      historySpanMonths: vehicle.historySpanMonths,
    );

    try {
      final repo = ref.read(carRepositoryProvider);
      final carId = await repo.publishFromVehicle(
        car: car,
        vehicleId: vehicle.id,
      );

      // Same cross-listing memory the ordinary publish writes, so an odometer
      // rollback is still catchable on a car listed this way. Best-effort: it
      // must never cost the seller their listing.
      try {
        await repo.recordPlateSnapshot(
          plate: car.plate,
          carId: carId,
          km: car.km,
          price: car.price,
          sellerType: car.sellerType,
          area: car.area,
        );
      } catch (_) {}

      if (mounted) context.pushReplacement('/car/$carId');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _publishing = false;
        _error = 'לא הצלחנו לפרסם. נסו שוב';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleAsync = ref.watch(vehicleProvider(widget.vehicleId));

    return Scaffold(
      appBar: AppBar(title: const Text('פרסום למכירה')),
      body: SafeArea(
        child: vehicleAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ErrorRetry(
            message: 'לא הצלחנו לטעון את הרכב',
            onRetry: () => ref.invalidate(vehicleProvider(widget.vehicleId)),
          ),
          data: (vehicle) =>
              vehicle == null ? const SizedBox.shrink() : _form(vehicle),
        ),
      ),
    );
  }

  Widget _form(Vehicle vehicle) {
    final colors = context.colors;
    final gov = vehicle.govSnapshot ?? const {};
    final services =
        ref.watch(vehicleServicesProvider(vehicle.id)).valueOrNull ?? const [];

    if (vehicle.isListed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('הרכב כבר מפורסם', style: AppText.h3),
              const SizedBox(height: AppSpace.md),
              Text(
                'כדי לפרסם מחדש, קודם הסירו את המודעה הקיימת.',
                textAlign: TextAlign.center,
                style: context.text.bodyMuted,
              ),
              if (vehicle.activeCarId != null) ...[
                const SizedBox(height: AppSpace.lg),
                OutlinedButton(
                  onPressed: () => context.push('/car/${vehicle.activeCarId}'),
                  child: const Text('פתח את המודעה'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpace.lg),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${gov['make'] ?? ''} ${gov['model'] ?? ''}'.trim(),
                style: AppText.title,
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                '${gov['year'] ?? ''} · ${_thousands(vehicle.currentKm)} ק"מ',
                style: context.text.caption,
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                'הפרטים והקילומטראז\' נלקחים מהתיק שלכם — אין מה להקליד שוב.',
                style: context.text.caption,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        if (services.isNotEmpty) _HistoryNotice(vehicle: vehicle),
        const SizedBox(height: AppSpace.lg),
        TextField(
          controller: _price,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'מחיר מבוקש (₪)'),
        ),
        const SizedBox(height: AppSpace.lg),
        TextField(
          controller: _area,
          decoration: const InputDecoration(
            labelText: 'אזור',
            hintText: 'תל אביב',
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        TextField(
          controller: _reason,
          decoration: const InputDecoration(labelText: 'סיבת המכירה'),
        ),
        const SizedBox(height: AppSpace.lg),
        TextField(
          controller: _description,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'כמה מילים על הרכב (לא חובה)',
          ),
        ),
        if (services.isNotEmpty) ...[
          const SizedBox(height: AppSpace.xl),
          const Text('מה שהקונה יראה', style: AppText.subtitle),
          const SizedBox(height: AppSpace.md),
          // The real widget, not a mockup of it — what is previewed here is
          // literally what renders on the listing.
          ServiceTimeline(records: services, showFooter: false),
        ],
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
          label: 'פרסם למכירה',
          loading: _publishing,
          onPressed: () => _publish(vehicle),
        ),
        const SizedBox(height: AppSpace.md),
        Text(
          'ההוצאות שלכם והמסמכים שלא סימנתם לשיתוף יישארו פרטיים.',
          style: context.text.caption,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _HistoryNotice extends StatelessWidget {
  const _HistoryNotice({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final badged = vehicle.hasDocumentedHistory;

    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: badged ? colors.tealLight : colors.warnBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(
            badged ? Icons.workspace_premium_outlined : Icons.info_outline,
            size: 20,
            color: badged ? colors.tealText : colors.warnText,
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(
              badged
                  ? 'התיק שלכם יוצג לקונים, והמודעה תסומן ב"תיק מתועד". '
                      '${vehicle.serviceCount} רשומות לאורך '
                      '${vehicle.historySpanMonths} חודשים.'
                  : 'התיק שלכם יוצג לקונים. הוא עדיין לא מזכה בתג "תיק מתועד" '
                      '— לזה צריך 3 רשומות לאורך חצי שנה.',
              style: AppText.bodySm.copyWith(
                color: badged ? colors.tealText : colors.warnText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _thousands(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
