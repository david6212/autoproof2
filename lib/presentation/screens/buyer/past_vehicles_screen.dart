import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/past_vehicle.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/skeleton.dart';

/// Cars the user used to own.
///
/// Read-only and frozen, and the screen says so. Once a car is handed over the
/// previous owner cannot see it any more — that is the same rule that makes
/// the history worth trusting, working in the direction that costs them
/// something. What they keep is a record of what they logged, not a window
/// into what the new owner does with it.
class PastVehiclesScreen extends ConsumerWidget {
  const PastVehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pastAsync = ref.watch(pastVehiclesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('רכבים שהיו בבעלותי')),
      body: SafeArea(
        child: pastAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 170, height: 18),
                SizedBox(height: AppSpace.md),
                Skeleton(width: 110),
              ],
            ),
          ),
          error: (_, __) => Center(
            child: Text('לא הצלחנו לטעון את הרשימה',
                style: context.text.bodyMuted),
          ),
          data: (past) =>
              past.isEmpty ? const _Empty() : _List(vehicles: past),
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.vehicles});

  final List<PastVehicle> vehicles;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpace.lg),
      itemCount: vehicles.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpace.md),
      itemBuilder: (_, i) {
        if (i == vehicles.length) {
          return Text(
            'הרשומות כאן מציגות את מה שתיעדתם עד יום המסירה. אחרי ההעברה '
            'התיק שייך לבעלים החדש ואינו נגיש לכם.',
            style: context.text.caption,
          );
        }
        return _PastCard(vehicle: vehicles[i]);
      },
    );
  }
}

class _PastCard extends StatelessWidget {
  const _PastCard({required this.vehicle});

  final PastVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final months = vehicle.ownedMonths;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vehicle.title.isEmpty ? 'רכב ${vehicle.plate}' : vehicle.title,
            style: AppText.title,
          ),
          const SizedBox(height: AppSpace.xs),
          Text(vehicle.plate, style: context.text.caption),
          const SizedBox(height: AppSpace.md),
          _Row(
            icon: Icons.build_outlined,
            text: vehicle.servicesLogged == 0
                ? 'לא תועדו טיפולים'
                : vehicle.servicesLogged == 1
                    ? 'טיפול אחד תועד ועבר עם הרכב'
                    : '${vehicle.servicesLogged} טיפולים תועדו ועברו עם הרכב',
          ),
          const SizedBox(height: AppSpace.sm),
          _Row(
            icon: Icons.swap_horiz,
            text: 'נמסר ב-${_date(vehicle.soldAt)}'
                '${months != null && months > 0 ? ' · אחרי $months חודשים' : ''}',
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 16, color: context.colors.textMuted),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Text(text, style: context.text.bodySmMuted)),
        ],
      );
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history, size: 48, color: context.colors.textSubtle),
              const SizedBox(height: AppSpace.lg),
              const Text('עוד לא מסרתם רכב', style: AppText.h3),
              const SizedBox(height: AppSpace.sm),
              Text(
                'רכב שתמסרו לקונה דרך BonnetCheck יופיע כאן, יחד עם מה '
                'שתיעדתם עליו.',
                textAlign: TextAlign.center,
                style: context.text.bodyMuted,
              ),
            ],
          ),
        ),
      );
}

String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';
