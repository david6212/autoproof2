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
}
