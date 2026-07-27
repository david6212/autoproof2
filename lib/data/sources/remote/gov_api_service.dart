import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';

/// Thrown when a plate lookup fails, carrying a Hebrew message for the UI.
class GovApiException implements Exception {
  GovApiException(this.message);
  final String message;
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
        throw GovApiException('המספר לא נמצא. בדוק את מספר הרישוי.');
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

  /// Fetches licensed pre-purchase inspection centers ("מכוני בדיקה") from the
  /// Ministry of Transport garages dataset, filtered to the pre-sale-inspection
  /// specialty. Returns the raw record maps, or throws GovApiException.
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
