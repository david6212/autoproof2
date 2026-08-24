import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/car_model.dart';
import '../providers/cars_provider.dart';
import '../providers/gov_api_provider.dart';
import 'app_card.dart';

/// Lets the seller re-take the registry answer stored on their listing.
///
/// Buyers no longer ask the registry themselves — they read what was stored
/// when the listing was published, because handing every visitor the plate is
/// what made the plate public in the first place. The cost of that is
/// freshness, and this is where it is paid: the seller can refresh, and the
/// date is on the listing either way.
///
/// It is the seller who can do this at all. The refresh needs the plate, and
/// the plate is theirs.
class RegistryRefreshCard extends ConsumerStatefulWidget {
  const RegistryRefreshCard({super.key, required this.car});

  final CarModel car;

  @override
  ConsumerState<RegistryRefreshCard> createState() =>
      _RegistryRefreshCardState();
}

class _RegistryRefreshCardState extends ConsumerState<RegistryRefreshCard> {
  bool _busy = false;

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      // The plate is no longer on the public listing document — it lives in
      // `cars/{id}/private/registry`, which only this seller can read. That
      // read is the reason this button belongs to them and to nobody else.
      final repo = ref.read(carRepositoryProvider);
      final plate = widget.car.plate.isNotEmpty
          ? widget.car.plate
          : await repo.plateFor(widget.car.id);
      if (plate.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('לא מצאנו את מספר הרישוי של המודעה הזו.'),
            ),
          );
        }
        return;
      }
      final gov =
          await ref.read(govApiRepositoryProvider).lookupPlate(plate);
      await repo.refreshGovSnapshot(widget.car.id, gov.toSnapshot());
      ref.invalidate(activeCarsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('נתוני המרשם עודכנו.')),
        );
      }
    } catch (_) {
      if (mounted) {
        // Named as ours, not as a fault in the listing: the registry not
        // answering says nothing about the car.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('לא הצלחנו להגיע למרשם כרגע. הנתונים הקודמים נשארו.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final at = widget.car.govCheckedAt;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('נתוני מרשם הרכב במודעה', style: AppText.subtitle),
          const SizedBox(height: AppSpace.xs),
          Text(
            at == null
                ? 'המודעה הזו פורסמה לפני שהנתונים נשמרו איתה. רעננו כדי '
                    'שהקונים יראו את מה שהמרשם אומר היום.'
                : 'נבדקו ב-${DateFormatter.format(at)}. הקונים רואים את התאריך '
                    'הזה לצד הנתונים.',
            style: context.text.bodySmMuted,
          ),
          const SizedBox(height: AppSpace.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _refresh,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 18),
              label: const Text('רענון נתוני המרשם'),
            ),
          ),
        ],
      ),
    );
  }
}
