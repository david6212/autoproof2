import '../../core/constants/api_constants.dart';
import '../../core/utils/plate_formatter.dart';
import '../models/gov_data_model.dart';
import '../models/fuel_station.dart';
import '../models/inspection_center.dart';
import '../models/licensed_garage.dart';
import '../models/model_spec.dart';
import '../sources/local/gov_cache.dart';
import '../sources/remote/gov_api_service.dart';

/// Turns a raw plate string into a parsed GovData object.
class GovApiRepository {
  GovApiRepository({GovApiService? service, GovCache? cache})
      : _service = service ?? GovApiService(),
        _cache = cache ?? GovCache();

  final GovApiService _service;
  final GovCache _cache;

  /// Reads a whole dataset, from the device first.
  ///
  /// The government asks not to be flooded, and these lists move slowly — so a
  /// cold start should not re-download every fuel station in the country. The
  /// order is: fresh copy on the device, else the network, else **a stale copy
  /// rather than nothing**, because a screen showing yesterday's stations
  /// beats an empty map when the connection is down.
  ///
  /// The plate lookup deliberately does not come through here: caching it
  /// would leave a list of plates on the device. See [GovCache].
  Future<List<T>> _dataset<T>({
    required String key,
    required Duration ttl,
    required Future<List<Map<String, dynamic>>> Function() fetch,
    required List<T> Function(List<Map<String, dynamic>>) parse,
  }) async {
    List<Map<String, dynamic>> rowsOf(Object? cached) => [
          for (final r in (cached as List? ?? const []))
            Map<String, dynamic>.from(r as Map),
        ];

    final fresh = await _cache.read(key, ttl);
    if (fresh != null) return parse(rowsOf(fresh));

    try {
      final raw = await fetch();
      await _cache.write(key, raw);
      return parse(raw);
    } catch (e) {
      final stale = await _cache.readStale(key);
      if (stale != null) return parse(rowsOf(stale));
      rethrow;
    }
  }

  /// When the cached copy of a dataset was taken, so a screen can say so
  /// rather than implying the figure is live.
  Future<DateTime?> datasetFetchedAt(String key) => _cache.writtenAt(key);

  static const fuelStationsKey = 'fuel_stations';
  static const inspectionCentersKey = 'inspection_centers';
  static const refineryPricesKey = 'refinery_prices';

  /// Looks up [rawPlate] (with or without dashes) and returns parsed data.
  /// Throws [GovApiException] with a Hebrew message on failure.
  Future<GovData> lookupPlate(String rawPlate) async {
    final digits = PlateFormatter.digitsOnly(rawPlate);
    if (digits.isEmpty) {
      throw GovApiException('יש להזין מספר רישוי.',
          kind: GovApiErrorKind.badInput);
    }
    // Off-road/scrapped vehicles are NOT in the active registry, so if the
    // active lookup fails, fall back to the off-road dataset (same fields).
    Map<String, dynamic> record;
    Map<String, dynamic>? offRoad;
    var offRoadAnswered = false;
    try {
      record = await _service.fetchByPlate(digits);
    } on GovApiException {
      offRoad = await _service.fetchOffRoad(digits);
      offRoadAnswered = true;
      if (offRoad == null) rethrow; // truly not found
      record = offRoad;
    }
    final base = GovData.fromApi(record);

    // Enrich with the extra datasets — each on its own.
    //
    // These are four separate endpoints and any one of them can time out or
    // rate-limit by itself. Awaited bare, as they were, a single sulking
    // auxiliary dataset threw out of this method, `govDataForPlateProvider`
    // caught it and returned null, and the listing page lost EVERY government
    // fact at once: the odometer comparison, the recall check, the structural
    // record. One endpoint's bad minute erased the entire reason the app
    // exists. `fetchModelSpec` had already been given this treatment, with the
    // note "an enrichment, never a blocker" — it was right, and it applied to
    // all four.
    //
    // What must NOT happen is quietly treating a failure as a clean result.
    // Each gap is recorded so the UI can stay silent about a check it never
    // ran, instead of reporting "nothing found".
    final missing = <GovDataset>{};

    Future<T?> tryFetch<T>(GovDataset which, Future<T> Function() fetch) async {
      try {
        return await fetch();
      } catch (_) {
        missing.add(which);
        return null;
      }
    }

    // Asked on every lookup, not only when the active registry misses.
    //
    // It used to run purely as a fallback, which meant that for a car that IS
    // in the registry the off-road register was never consulted — while the
    // listing page told the reader it had been. The check is cheap; the claim
    // was not ours to make.
    if (!offRoadAnswered) {
      offRoad = await tryFetch<Map<String, dynamic>?>(
        GovDataset.offRoad,
        () => _service.fetchOffRoad(digits),
      );
    }

    final history =
        await tryFetch(GovDataset.history, () => _service.fetchHistory(digits));
    final rawRecalls =
        await tryFetch(GovDataset.recalls, () => _service.fetchRecalls(digits));
    final recalls = (rawRecalls ?? const <Map<String, dynamic>>[])
        .map((r) => RecallItem(
              system: (r['SUG_TAKALA'] ?? '').toString(),
              description: (r['TEUR_TAKALA'] ?? '').toString(),
              date: (r['TAARICH_PTICHA'] ?? '').toString().split(' ').first,
            ))
        .toList();

    // Engine capacity, seats, drivetrain and body type come from the separate
    // models dataset, keyed by manufacturer + model + year.
    final specRaw = await _service.fetchModelSpec(
      tozeretCd: base.tozeretCd,
      degemCd: base.degemCd,
      year: base.year,
    );

    return base
        .withExtras(
          history: history,
          recalls: recalls,
          offRoad: offRoad,
          missing: missing,
        )
        .withSpec(specRaw == null ? null : ModelSpec.fromApi(specRaw));
  }

  /// Licensed garages for a trade, nearest-agnostic and sorted by town.
  ///
  /// Returns nothing for a trade the ministry does not license — car washes —
  /// rather than pretending the registry had no matches. The two are not the
  /// same and the caller has to be able to tell them apart.
  Future<List<LicensedGarage>> garagesFor(
    GarageTrade trade, {
    String? town,
  }) async {
    if (!trade.isLicensed) return const [];
    final raw = await _service.fetchGarages(
      miktzoaValues: trade.miktzoaValues,
      town: town,
    );
    final list = raw
        .map(LicensedGarage.fromApi)
        .where((g) => g.name.isNotEmpty && g.licenceNumber.isNotEmpty)
        .toList();
    list.sort((a, b) {
      final byTown = a.town.compareTo(b.town);
      return byTown != 0 ? byTown : a.name.compareTo(b.name);
    });
    return list;
  }

  /// Licensed pre-purchase inspection centers, cleaned and sorted by city then
  /// name. Drops records with no usable name.
  Future<List<InspectionCenter>> inspectionCenters() => _dataset(
        key: inspectionCentersKey,
        ttl: GovCache.inspectionCentersTtl,
        fetch: _service.fetchInspectionCenters,
        parse: _parseCenters,
      );

  static List<InspectionCenter> _parseCenters(List<Map<String, dynamic>> raw) {
    final list = raw
        .map(InspectionCenter.fromApi)
        .where((c) => c.name.isNotEmpty)
        .toList();
    list.sort((a, b) {
      final byCity = a.city.compareTo(b.city);
      return byCity != 0 ? byCity : a.name.compareTo(b.name);
    });
    return list;
  }

  /// Every legal public fuel station, nearest-agnostic (the screen sorts by
  /// distance once it knows where the user is).
  ///
  /// Two of the 1,255 rows ship without coordinates and a stray row could put
  /// a pin in the sea, so anything outside Israel's bounding box is dropped
  /// rather than drawn — [FuelStation.plausible] also catches a lat/lng swap.
  Future<List<FuelStation>> fuelStations() => _dataset(
        key: fuelStationsKey,
        ttl: GovCache.fuelStationsTtl,
        fetch: _service.fetchFuelStations,
        parse: (raw) {
          final list = raw
              .map(FuelStation.fromApi)
              .where((s) => s.name.isNotEmpty && s.plausible)
              .toList();
          list.sort((a, b) {
            final byCity = a.city.compareTo(b.city);
            return byCity != 0 ? byCity : a.displayName.compareTo(b.displayName);
          });
          return list;
        },
      );

  /// The most recent refinery-gate diesel figure, or null if the dataset has
  /// nothing usable. Deliberately a single number with its month attached —
  /// it is a reference, not a price anyone pays.
  Future<FuelReference?> dieselReference() async {
    final list = await _dataset(
      key: refineryPricesKey,
      ttl: GovCache.refineryPricesTtl,
      fetch: _service.fetchRefineryPrices,
      parse: (raw) {
        final diesel = raw
            .map(FuelReference.fromApi)
            .where((p) => p.product == ApiConstants.dieselProduct)
            .where((p) => p.shekelsPerLitre > 0)
            .toList();
        diesel.sort((a, b) => b.date.compareTo(a.date));
        return diesel;
      },
    );
    return list.isEmpty ? null : list.first;
  }
}
