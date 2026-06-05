import 'package:dio/dio.dart';

import '../../../core/errors/exceptions.dart';

/// Lightweight warehouse list — reads ERPNext's standard Warehouse list
/// endpoint directly, no `bude_api` indirection needed for read-only lookups.
class WarehouseRemoteDataSource {
  final Dio dio;
  WarehouseRemoteDataSource(this.dio);

  Future<List<String>> list({int limit = 100}) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/resource/Warehouse',
        queryParameters: {
          'fields': '["name"]',
          'filters': '[["disabled","=",0]]',
          'limit_page_length': limit,
          'order_by': 'name asc',
        },
      );
      final raw = response.data?['data'];
      if (raw is! List) {
        throw const ServerException('Unexpected warehouse list response.');
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
