import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/odometer_check.dart';
import '../../../core/utils/relisting_check.dart';
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
/// [StatelessWidget] over a list — easy to test with five hand-written
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

    // --- this plate's other listings ---
    //
    // The history has been on the listing since the rollback check was built;
    // nothing was asking it who else has had the car on the market. Two
    // separate questions, and only the first is a warning.
    final earlier = RelistingCheck.previous(
      currentCarId: car.id,
      history: history,
      activeCarIds:
          ref.watch(concurrentListingsProvider([for (final s in history) s.carId]))
                  .valueOrNull ??
              const <String>{},
    );

    final live = RelistingCheck.concurrent(earlier);
    if (live.isNotEmpty) {
      warnings.add(ActiveWarning.alsoListedNow(
        count: live.length,
        otherPrice: RelistingCheck.shekels(live.first.snapshot.price),
        otherArea: live.first.snapshot.area,
      ));
    }

    // Informational rather than accusatory: buying a car and reselling it is a
    // legal business, and what the buyer gains here is the earlier number.
    final flip = RelistingCheck.recentSellerChange(
      previous: earlier,
      currentSellerType: car.sellerType,
      now: DateTime.now(),
    );
    if (flip != null) {
      warnings.add(ActiveWarning.soldOnRecently(
        pastSeller: flip.snapshot.sellerType.label,
        pastPrice: RelistingCheck.shekels(flip.snapshot.price),
        pastDate: DateFormatter.format(flip.snapshot.createdAt),
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

    // Severity first, so the thing that can stop a purchase is never below
    // the thing that merely deserves a question.
    warnings.sort((a, b) => a.severity.index.compareTo(b.severity.index));
    return warnings;
  }
}
