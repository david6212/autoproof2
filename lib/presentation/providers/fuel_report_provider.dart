import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/fuel_report.dart';
import '../../data/repositories/fuel_report_repository.dart';
import 'auth_provider.dart';

final fuelReportRepositoryProvider =
    Provider<FuelReportRepository>((ref) => FuelReportRepository());

/// Live diesel tally for one station.
final fuelTallyProvider =
    StreamProvider.family<FuelPriceTally, String>((ref, stationId) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  return ref
      .read(fuelReportRepositoryProvider)
      .streamTally(stationId, uid);
});

/// Fresh medians for every station that has any, so the list can be sorted by
/// price. Deliberately a one-shot read rather than a stream — 1,255 live
/// listeners would be absurd, and a price that is minutes stale changes
/// nothing about which station is cheaper.
final fuelMediansProvider = FutureProvider<Map<String, int>>((ref) async {
  try {
    return await ref.read(fuelReportRepositoryProvider).recentMedians();
  } catch (_) {
    // Sorting by price is a bonus; the map must still work without it.
    return const {};
  }
});
