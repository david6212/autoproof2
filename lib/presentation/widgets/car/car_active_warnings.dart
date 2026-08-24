import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/odometer_check.dart';
import '../../../data/models/plate_snapshot_model.dart';
import '../../../data/models/car_model.dart';
import '../../../data/models/gov_data_model.dart';
import '../../providers/cars_provider.dart';
import '../../providers/gov_api_provider.dart';
import 'active_warnings_section.dart';

/// Gathers this listing's findings from the three places that hold them and
/// hands them to [ActiveWarningsSection].
///
/// Kept apart from the section itself so the presentation stays a plain
/// [StatelessWidget] over a list — easy to test with six hand-written
/// findings, and impossible to accidentally couple to Firestore.
///
/// Nothing here decides anything new. Every rule below is the one already
/// running inside the panel further down the page; this widget only pulls the
/// answers to the top, where a buyer scrolling fast will still see them.
class CarActiveWarnings extends ConsumerWidget {
  const CarActiveWarnings({
    super.key,
    required this.car,
    this.onShowOdometerSource,
  });

  final CarModel car;

  /// Scrolls the reader to the odometer panel — the evidence behind the
  /// finding, rather than a repeat of it.
  final VoidCallback? onShowOdometerSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ActiveWarningsSection(warnings: _collect(ref));
  }

  List<ActiveWarning> _collect(WidgetRef ref) {
    final gov = listingGov(ref, car).valueOrNull;
    final history =
        [
      for (final m
          in car.plateHistorySnapshot ?? const <Map<String, dynamic>>[])
        PlateSnapshot.fromMap(m),
    ];
    final tally = ref.watch(encounterTallyProvider(car.id)).valueOrNull;

    final warnings = <ActiveWarning>[];

    // --- odometer, against the registry ---
    final officialKm = OdometerCheck.officialReading(gov?.lastTestKm);
    if (OdometerCheck.belowOfficial(
        officialKm: officialKm, currentKm: car.km)) {
      warnings.add(ActiveWarning.odometerBelowOfficial(
        listedKm: car.km,
        officialKm: officialKm!,
        testDate: gov?.lastTestDate == null
            ? 'הטסט האחרון'
            : DateFormatter.format(gov!.lastTestDate!),
        actionLabel: onShowOdometerSource == null ? null : 'הצג את המקור',
        onAction: onShowOdometerSource,
      ));
    }

    // --- odometer, against this plate's earlier listings ---
    final previous = history.where((s) => s.carId != car.id).toList();
    final higher =
        OdometerCheck.highestAbove(previous: previous, currentKm: car.km);
    if (higher != null) {
      warnings.add(ActiveWarning.odometerBelowPastListing(
        pastKm: higher.km,
        currentKm: car.km,
        pastDate: DateFormatter.format(higher.createdAt),
      ));
    }

    // --- the registry's own flags ---
    //
    // Each guarded by whether its dataset answered. A finding we cannot make
    // is not the same as a finding of nothing, and the difference matters in
    // both directions: silence here has to mean "the record is clean", never
    // "we could not reach the record".
    if (gov != null) {
      if (gov.offRoad) warnings.add(ActiveWarning.offRoad());
      if (gov.answered(GovDataset.history) && gov.structuralChange) {
        warnings.add(ActiveWarning.structuralChange());
      }
      if (gov.answered(GovDataset.recalls) && gov.recalls.isNotEmpty) {
        warnings.add(ActiveWarning.openRecall(count: gov.recalls.length));
      }
    }

    // --- what buyers who met the seller say ---
    if (tally != null && tally.disagreesWith(car.sellerType)) {
      final majority = tally.majority!;
      warnings.add(ActiveWarning.sellerTypeDisagreement(
        declared: car.sellerType.label,
        reported: majority.label,
        total: tally.total,
        agreeing: tally.countFor(majority),
      ));
    }

    // Severity first, so the thing that can stop a purchase is never below
    // the thing that merely deserves a question.
    warnings.sort((a, b) => a.severity.index.compareTo(b.severity.index));
    return warnings;
  }
}
