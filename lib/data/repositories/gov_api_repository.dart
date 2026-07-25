import '../../core/utils/plate_formatter.dart';
import '../models/gov_data_model.dart';
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
    final record = await _service.fetchByPlate(digits);
    final base = GovData.fromApi(record);

    // Enrich with history (km, structural change) + open recalls in parallel.
    final results = await Future.wait([
      _service.fetchHistory(digits),
      _service.fetchRecalls(digits),
    ]);
    final history = results[0] as Map<String, dynamic>?;
    final rawRecalls = (results[1] as List).cast<Map<String, dynamic>>();
    final recalls = rawRecalls
        .map((r) => RecallItem(
              system: (r['SUG_TAKALA'] ?? '').toString(),
              description: (r['TEUR_TAKALA'] ?? '').toString(),
              date: (r['TAARICH_PTICHA'] ?? '').toString().split(' ').first,
            ))
        .toList();

    return base.withExtras(history: history, recalls: recalls);
  }
}
