import 'package:dio/dio.dart';

import '../../../core/errors/exceptions.dart';

/// Reads submitted Purchase Orders directly via the standard
/// /api/resource/Purchase%20Order endpoint. Used by the Receipt screen's
/// optional PO picker.
class PurchaseOrderRemoteDataSource {
  final Dio dio;
  PurchaseOrderRemoteDataSource(this.dio);

  Future<List<String>> listOpen({int limit = 50}) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/resource/Purchase Order',
        queryParameters: {
          'fields': '["name"]',
          // Only submitted POs that aren't fully received.
          'filters': '[["docstatus","=",1],["status","not in",["Closed","Completed","Cancelled"]]]',
          'limit_page_length': limit,
          'order_by': 'transaction_date desc',
        },
      );
      final raw = response.data?['data'];
      if (raw is! List) {
        throw const ServerException('Unexpected PO list response.');
      }
      return raw
          .cast<Map<String, dynamic>>()
          .map((row) => row['name'] as String)
          .toList();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        throw const AuthException('Authentication required.');
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.receiveTimeout) {
        throw NetworkException(e.message ?? 'Network unreachable.');
      }
      throw ServerException(e.message ?? 'Server error.', statusCode: status);
    }
  }
}
