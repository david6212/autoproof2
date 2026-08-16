import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/vehicle.dart';
import '../../../data/models/vehicle_reminder.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/guest_prompt_view.dart';
import '../../widgets/primary_button_widget.dart';
import '../../widgets/skeleton.dart';

/// "הרכב שלי" — the owner's garage.
///
/// This is the half of the app that exists after the sale. Everything else
/// here helps someone buy a car and then has no reason to be opened again;
/// this is where a car lives for the years in between, which is the only
/// reason an owner would still have the app installed when they come to sell.
class GarageScreen extends ConsumerWidget {
  const GarageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(authStateProvider).valueOrNull == null;
    final vehiclesAsync = ref.watch(myVehiclesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('הרכב שלי'),
        actions: [
          if (!isGuest && (vehiclesAsync.valueOrNull?.isNotEmpty ?? false)) ...[
            IconButton(
              icon: const Icon(Icons.key_outlined),
              tooltip: 'קניתי רכב דרך BonnetCheck',
              onPressed: () => context.push('/garage/claim'),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'הוסף רכב',
              onPressed: () => context.push('/garage/add'),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: isGuest
            ? const GuestPromptView(
                icon: Icons.directions_car_outlined,
                title: 'התיק של הרכב שלך',
                body: 'התחברו כדי לנהל את הרכב שלכם — טיפולים, הוצאות ומסמכים '
                    'במקום אחד.',
              )
            : vehiclesAsync.when(
                loading: () => const _GarageSkeleton(),
                error: (_, __) => _ErrorView(
                  onRetry: () => ref.invalidate(myVehiclesProvider),
                ),
                data: (vehicles) => vehicles.isEmpty
                    ? const _EmptyGarage()
                    : _VehicleList(vehicles: vehicles),
              ),
      ),
    );
  }
}

class _VehicleList extends StatelessWidget {
  const _VehicleList({required this.vehicles});

  final List<Vehicle> vehicles;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpace.lg),
      itemCount: vehicles.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpace.md),
      itemBuilder: (_, i) => _VehicleCard(vehicle: vehicles[i]),
    );
  }
}

class _VehicleCard extends ConsumerWidget {
  const _VehicleCard({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gov = vehicle.govSnapshot ?? const {};
    final modelName = [gov['make'], gov['model']]
        .where((v) => v != null && '$v'.trim().isNotEmpty)
        .join(' ');
    final title = vehicle.titleWith(
      modelName.isNotEmpty ? modelName : 'רכב ${vehicle.plate}',
    );

    final reminders = ref.watch(vehicleRemindersProvider(vehicle.id));
    final next = _nextReminder(reminders.valueOrNull ?? const []);

    return AppCard(
      onTap: () => context.push('/vehicle/${vehicle.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppText.title)),
              if (vehicle.hasDocumentedHistory) const _DocumentedBadge(),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            _plateDisplay(vehicle.plate),
            style: context.text.caption,
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              _Stat(
                icon: Icons.build_outlined,
                label: vehicle.serviceCount == 1
                    ? 'טיפול אחד'
                    : '${vehicle.serviceCount} טיפולים',
              ),
              const SizedBox(width: AppSpace.lg),
              if (vehicle.currentKm > 0)
                _Stat(
                  icon: Icons.speed_outlined,
                  label: '${_thousands(vehicle.currentKm)} ק"מ',
                ),
            ],
          ),
          if (next != null) ...[
            const SizedBox(height: AppSpace.md),
            _ReminderStrip(reminder: next),
          ],
        ],
      ),
    );
  }

  static VehicleReminder? _nextReminder(List<VehicleReminder> all) {
    for (final r in all) {
      if (r.isDueSoon) return r;
    }
    return null;
  }
}

class _ReminderStrip extends StatelessWidget {
  const _ReminderStrip({required this.reminder});

  final VehicleReminder reminder;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final overdue = reminder.isOverdue;
    final days = reminder.daysUntilDue ?? 0;

    final text = overdue
        ? '${reminder.title} — עבר התאריך ב-${days.abs()} ימים'
        : days == 0
            ? '${reminder.title} — היום'
            : '${reminder.title} בעוד $days ימים';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: overdue ? colors.errorBg : colors.warnBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(
            overdue ? Icons.error_outline : Icons.schedule,
            size: 18,
            color: overdue ? colors.errorRed : colors.warnText,
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              text,
              style: AppText.bodySm.copyWith(
                color: overdue ? colors.errorRed : colors.warnText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentedBadge extends StatelessWidget {
  const _DocumentedBadge();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.tealLight,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        'תיק מתועד',
        style: AppText.bodySm.copyWith(
          color: colors.tealText,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: context.colors.textMuted),
        const SizedBox(width: AppSpace.xs),
        Text(label, style: context.text.bodySmMuted),
      ],
    );
  }
}

class _EmptyGarage extends StatelessWidget {
  const _EmptyGarage();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_car_outlined, size: 56, color: colors.teal),
            const SizedBox(height: AppSpace.lg),
            const Text('אין כאן רכב עדיין', style: AppText.h3),
            const SizedBox(height: AppSpace.sm),
            Text(
              'הוסיפו את הרכב שלכם ותוכלו לתעד טיפולים, לעקוב אחרי ההוצאות '
              'ולשמור מסמכים במקום אחד. כשתרצו למכור — הכול כבר יהיה שם.',
              textAlign: TextAlign.center,
              style: context.text.bodyMuted,
            ),
            const SizedBox(height: AppSpace.xl),
            PrimaryButton(
              label: 'הוסף רכב',
              onPressed: () => context.push('/garage/add'),
            ),
            const SizedBox(height: AppSpace.sm),
            TextButton(
              onPressed: () => context.push('/garage/claim'),
              child: const Text('קניתי רכב דרך BonnetCheck'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GarageSkeleton extends StatelessWidget {
  const _GarageSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpace.lg),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpace.md),
      itemBuilder: (_, __) => const AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 160, height: 18),
            SizedBox(height: AppSpace.sm),
            Skeleton(width: 90),
            SizedBox(height: AppSpace.lg),
            Skeleton(width: 200),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: context.colors.textSubtle),
            const SizedBox(height: AppSpace.lg),
            const Text('לא הצלחנו לטעון את הרכבים', style: AppText.subtitle),
            const SizedBox(height: AppSpace.lg),
            OutlinedButton(onPressed: onRetry, child: const Text('נסו שוב')),
          ],
        ),
      ),
    );
  }
}

/// Israeli plates read 12-345-67 or 123-45-678 depending on length.
String _plateDisplay(String plate) {
  if (plate.length == 7) {
    return '${plate.substring(0, 2)}-${plate.substring(2, 5)}-${plate.substring(5)}';
  }
  if (plate.length == 8) {
    return '${plate.substring(0, 3)}-${plate.substring(3, 5)}-${plate.substring(5)}';
  }
  return plate;
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
