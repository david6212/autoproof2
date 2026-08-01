import '../../core/utils/plate_formatter.dart';
import '../models/gov_data_model.dart';
import '../models/inspection_center.dart';
import '../models/model_spec.dart';
import '../sources/remote/gov_api_service.dart';

/// Turns a raw plate string into a parsed GovData object.
class GovApiRepository {
  GovApiRepository({GovApiService? service})
      : _service = service ?? GovApiService();

  final GovApiService _service;

  /// Looks up [rawPlate] (with or without dashes) and returns parsed data.
  /// Throws [GovApiException] with a Hebrew message on failure.
  Future<GovData> lookupPlate(String rawPlate) async {
    final digits = PlateFormatter.digitsOnly(rawPlate);
    if (digits.isEmpty) {
      throw GovApiException('יש להזין מספר רישוי.');
    }
    // Off-road/scrapped vehicles are NOT in the active registry, so if the
    // active lookup fails, fall back to the off-road dataset (same fields).
    Map<String, dynamic> record;
    Map<String, dynamic>? offRoad;
    try {
      record = await _service.fetchByPlate(digits);
    } on GovApiException {
      offRoad = await _service.fetchOffRoad(digits);
      if (offRoad == null) rethrow; // truly not found
      record = offRoad;
    }
    final base = GovData.fromApi(record);

    // Enrich with the extra datasets.
    final history = await _service.fetchHistory(digits);
    final rawRecalls = await _service.fetchRecalls(digits);
    final disabilityTag = await _service.fetchDisabilityTag(digits);
    final recalls = rawRecalls
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
          disabilityTag: disabilityTag,
        )
        .withSpec(specRaw == null ? null : ModelSpec.fromApi(specRaw));
  }

  /// Licensed pre-purchase inspection centers, cleaned and sorted by city then
  /// name. Drops records with no usable name.
  Future<List<InspectionCenter>> inspectionCenters() async {
    final raw = await _service.fetchInspectionCenters();
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
}
