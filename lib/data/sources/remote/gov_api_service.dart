import 'dart:convert';
import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';

/// Thrown when a plate lookup fails, carrying a Hebrew message for the UI.
/// Why a registry call failed.
///
/// The message alone was not enough to act on. "This plate is not in the
/// registry" and "we could not reach the registry" read almost the same to a
/// caller matching on strings, and they call for opposite behaviour: the first
/// is an answer, the second is the absence of one. An app whose entire claim
/// is that it shows official records cannot afford to render the second as the
/// first.
enum GovApiErrorKind {
  /// The registry answered, and has no such vehicle.
  notFound,

  /// We never got an answer — timeout, network, CORS, an error status.
  unreachable,

  /// The plate we were handed was not usable.
  badInput,
}

class GovApiException implements Exception {
  GovApiException(this.message, {this.kind = GovApiErrorKind.unreachable});

  final String message;
  final GovApiErrorKind kind;

  bool get isNotFound => kind == GovApiErrorKind.notFound;

  @override
  String toString() => message;
}

/// Low-level HTTP client for the data.gov.il datastore_search endpoint.
class GovApiService {
  GovApiService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
            ));

  final Dio _dio;

  /// Returns the raw record map for a plate, or throws GovApiException.
  Future<Map<String, dynamic>> fetchByPlate(String plateDigits) async {
    try {
      final res = await _dio.get(
        ApiConstants.govApiBase,
        queryParameters: {
          'resource_id': ApiConstants.vehicleResourceId,
          'q': plateDigits,
          'limit': 1,
        },
      );

      final data = res.data;
      if (data is! Map || data['success'] != true) {
        throw GovApiException('שירות הנתונים הממשלתי אינו זמין כרגע.');
      }

      final records = (data['result']?['records'] as List?) ?? const [];
      if (records.isEmpty) {
        throw GovApiException('המספר לא נמצא. בדוק את מספר הרישוי.',
            kind: GovApiErrorKind.notFound);
      }

      return Map<String, dynamic>.from(records.first as Map);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw GovApiException('הבקשה ארכה מדי. בדוק את החיבור לאינטרנט.');
      }
      throw GovApiException('שגיאת רשת. נסה שוב.');
    }
  }

  /// Best-effort fetch of the per-MODEL spec (engine capacity, seats,
  /// drivetrain, body type), which the per-vehicle registry doesn't carry.
  /// Returns null when the model isn't listed — common for older or imported
  /// cars — so callers must treat the spec as optional.
  Future<Map<String, dynamic>?> fetchModelSpec({
    required String tozeretCd,
    required String degemCd,
    required int year,
  }) async {
    if (tozeretCd.isEmpty || degemCd.isEmpty || year == 0) return null;
    try {
      final filters =
          '{"tozeret_cd":"$tozeretCd","degem_cd":"$degemCd","shnat_yitzur":"$year"}';
      final res = await _dio.get(ApiConstants.govApiBase, queryParameters: {
        'resource_id': ApiConstants.modelSpecResourceId,
        'filters': filters,
        'limit': 1,
      });
      final records = (res.data?['result']?['records'] as List?) ?? const [];
      if (records.isEmpty) return null;
      return Map<String, dynamic>.from(records.first as Map);
    } catch (_) {
      return null; // an enrichment, never a blocker
    }
  }

  /// Fetches licensed pre-purchase inspection centers ("מכוני בדיקה") from the
  /// Ministry of Transport garages dataset, filtered to the pre-sale-inspection
  /// specialty. Returns the raw record maps, or throws GovApiException.
  /// Every public fuel station. All 1,255 come back in one request, so there
  /// is no paging to get wrong.
  Future<List<Map<String, dynamic>>> fetchFuelStations() =>
      _records(ApiConstants.fuelStationsResourceId, limit: 2000);

  /// Refinery-gate prices. 204 monthly rows across all products; the caller
  /// picks the latest diesel one.
  Future<List<Map<String, dynamic>>> fetchRefineryPrices() =>
      _records(ApiConstants.refineryPricesResourceId, limit: 500);

  /// The shared shape of a datastore read: same success check, same error
  /// wording, so a new dataset does not mean a new copy of both.
  Future<List<Map<String, dynamic>>> _records(
    String resourceId, {
    required int limit,
    Map<String, dynamic> extra = const {},
  }) async {
    try {
      final res = await _dio.get(
        ApiConstants.govApiBase,
        queryParameters: {
          'resource_id': resourceId,
          'limit': limit,
          ...extra,
        },
      );
      final data = res.data;
      if (data is! Map || data['success'] != true) {
        throw GovApiException('שירות הנתונים הממשלתי אינו זמין כרגע.');
      }
      final records = (data['result']?['records'] as List?) ?? const [];
      return records.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw GovApiException('הבקשה ארכה מדי. בדוק את החיבור לאינטרנט.');
      }
      throw GovApiException('שגיאת רשת. נסה שוב.');
    }
  }

  Future<List<Map<String, dynamic>>> fetchInspectionCenters() async {
    try {
      final res = await _dio.get(
        ApiConstants.govApiBase,
        queryParameters: {
          'resource_id': ApiConstants.garagesResourceId,
          'filters': '{"miktzoa":"${ApiConstants.inspectionMiktzoa}"}',
          'limit': 500,
        },
      );
      final data = res.data;
      if (data is! Map || data['success'] != true) {
        throw GovApiException('שירות הנתונים הממשלתי אינו זמין כרגע.');
      }
      final records = (data['result']?['records'] as List?) ?? const [];
      return records
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw GovApiException('הבקשה ארכה מדי. בדוק את החיבור לאינטרנט.');
      }
      throw GovApiException('שגיאת רשת. נסה שוב.');
    }
  }

  /// Licensed garages for one or more `miktzoa` values, optionally narrowed
  /// to a town.
  ///
  /// Filtered server-side. The registry holds 13,930 rows and the app has no
  /// business downloading them to find the four in somebody's town — CKAN
  /// accepts a list of values per field, so one request answers the whole
  /// question.
  Future<List<Map<String, dynamic>>> fetchGarages({
    required List<String> miktzoaValues,
    String? town,
    int limit = 200,
  }) async {
    if (miktzoaValues.isEmpty) return const [];
    try {
      final filters = <String, dynamic>{'miktzoa': miktzoaValues};
      if (town != null && town.trim().isNotEmpty) {
        filters['yishuv'] = town.trim();
      }
      final res = await _dio.get(
        ApiConstants.govApiBase,
        queryParameters: {
          'resource_id': ApiConstants.garagesResourceId,
          'filters': jsonEncode(filters),
          'limit': limit,
        },
      );
      final data = res.data;
      if (data is! Map || data['success'] != true) {
        throw GovApiException('שירות הנתונים הממשלתי אינו זמין כרגע.');
      }
      final records = (data['result']?['records'] as List?) ?? const [];
      return records.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw GovApiException('הבקשה ארכה מדי. בדוק את החיבור לאינטרנט.');
      }
      throw GovApiException('שגיאת רשת. נסה שוב.');
    }
  }

  /// Best-effort fetch of the vehicle-history record (km at last test,
  /// structural change...). Returns null if missing — that's normal.
  Future<Map<String, dynamic>?> fetchHistory(String plateDigits) async {
    try {
      final res = await _dio.get(ApiConstants.govApiBase, queryParameters: {
        'resource_id': ApiConstants.vehicleHistoryResourceId,
        'q': plateDigits,
        'limit': 5,
      });
      final records =
          (res.data?['result']?['records'] as List?) ?? const [];
      for (final r in records) {
        if ('${(r as Map)['mispar_rechev']}' == plateDigits) {
          return Map<String, dynamic>.from(r);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Best-effort fetch of open (unperformed) recalls for the plate.
  /// Empty list = no open recalls (good).
  Future<List<Map<String, dynamic>>> fetchRecalls(String plateDigits) async {
    try {
      final res = await _dio.get(ApiConstants.govApiBase, queryParameters: {
        'resource_id': ApiConstants.openRecallResourceId,
        'q': plateDigits,
        'limit': 20,
      });
      final records =
          (res.data?['result']?['records'] as List?) ?? const [];
      return records
          .where((r) => '${(r as Map)['MISPAR_RECHEV']}' == plateDigits)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Best-effort: is the vehicle off the road / finally cancelled (scrapped)?
  /// Returns the record (with bitul_dt) if so, else null.
  Future<Map<String, dynamic>?> fetchOffRoad(String plateDigits) async {
    try {
      final res = await _dio.get(ApiConstants.govApiBase, queryParameters: {
        'resource_id': ApiConstants.offRoadResourceId,
        'q': plateDigits,
        'limit': 5,
      });
      final records =
          (res.data?['result']?['records'] as List?) ?? const [];
      for (final r in records) {
        if ('${(r as Map)['mispar_rechev']}' == plateDigits) {
          return Map<String, dynamic>.from(r);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Best-effort: does the vehicle have a disability parking tag?
  Future<bool> fetchDisabilityTag(String plateDigits) async {
    try {
      final res = await _dio.get(ApiConstants.govApiBase, queryParameters: {
        'resource_id': ApiConstants.disabilityTagResourceId,
        'q': plateDigits,
        'limit': 5,
      });
      final records =
          (res.data?['result']?['records'] as List?) ?? const [];
      return records.any((r) => '${(r as Map)['MISPAR RECHEV']}' == plateDigits);
    } catch (_) {
      return false;
    }
  }
}
