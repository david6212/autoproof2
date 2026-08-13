import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/gov_data_model.dart';
import '../../data/models/fuel_station.dart';
import '../../data/models/inspection_center.dart';
import '../../data/repositories/gov_api_repository.dart';
import '../../data/sources/remote/gov_api_service.dart';

final govApiRepositoryProvider = Provider<GovApiRepository>((ref) {
  return GovApiRepository();
});

/// Licensed pre-purchase inspection centers nationwide (official gov data),
/// enriched with coordinates from the bundled geocode asset so they can be
/// pinned on a map. Cached for the session — the list rarely changes.
final inspectionCentersProvider =
    FutureProvider<List<InspectionCenter>>((ref) async {
  final centers = await ref.read(govApiRepositoryProvider).inspectionCenters();

  // Attach pre-geocoded coordinates (asset keyed by normalized name|city).
  Map<String, dynamic> geo = const {};
  try {
    final raw =
        await rootBundle.loadString('assets/data/inspection_centers_geo.json');
    geo = jsonDecode(raw) as Map<String, dynamic>;
  } catch (_) {
    // No asset / parse error → centers just render without pins.
  }

  return centers.map((c) {
    final coord = geo[c.geoKey];
    if (coord is List && coord.length >= 2) {
      return c.withCoords(
        (coord[0] as num).toDouble(),
        (coord[1] as num).toDouble(),
        coord.length > 2 ? '${coord[2]}' : 'city',
      );
    }
    return c;
  }).toList();
});

/// Fetches official gov data for a plate (used by the car page to cross-check
/// the odometer). Returns null on any failure — it's an enhancement, never a
/// blocker.
final govDataForPlateProvider =
    FutureProvider.family<GovData?, String>((ref, plate) async {
  try {
    return await ref.read(govApiRepositoryProvider).lookupPlate(plate);
  } catch (_) {
    return null;
  }
});

/// Holds the result of a single plate lookup.
/// - AsyncData(null): idle, nothing searched yet
/// - AsyncLoading: searching
/// - AsyncData(GovData): success
/// - AsyncError: failure (message is Hebrew)
class GovLookupController extends AutoDisposeAsyncNotifier<GovData?> {
  @override
  Future<GovData?> build() async => null;

  Future<void> search(String rawPlate) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        return await ref.read(govApiRepositoryProvider).lookupPlate(rawPlate);
      } on GovApiException catch (e) {
        throw e.message; // surface the Hebrew message as the error object
      }
    });
  }

  void clear() => state = const AsyncData(null);
}

final govLookupControllerProvider =
    AutoDisposeAsyncNotifierProvider<GovLookupController, GovData?>(
  GovLookupController.new,
);


/// Every public fuel station, fetched once per session. The list is ~1,255
/// rows and never changes while the app is open.
final fuelStationsProvider = FutureProvider<List<FuelStation>>(
    (ref) => ref.read(govApiRepositoryProvider).fuelStations());

/// The refinery-gate diesel reference. Nullable and non-blocking: the map is
/// still useful without it, so a failure here must never take the screen down.
final dieselReferenceProvider = FutureProvider<FuelReference?>((ref) async {
  try {
    return await ref.read(govApiRepositoryProvider).dieselReference();
  } catch (_) {
    return null;
  }
});
