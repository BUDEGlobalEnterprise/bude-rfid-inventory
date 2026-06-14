import 'package:dio/dio.dart';

import '../../../core/errors/exceptions.dart';

class WarehouseRemoteDataSource {
  final Dio dio;
  WarehouseRemoteDataSource(this.dio);

  Future<List<String>> list({int limit = 100}) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/method/bude_api.api.warehouses.list',
        queryParameters: {'limit': limit},
      );
      // Frappe wraps method results in {"message": {...}}.
      final envelope = response.data?['message'];
      if (envelope is! Map) {
        throw const ServerException('Unexpected warehouse list response.');
      }
      final body = envelope.cast<String, dynamic>();
      if (body['ok'] != true) {
        throw ServerException(
          (body['message'] as String?) ?? 'Failed to load warehouses.',
        );
      }
      final raw = body['data'];
      if (raw is! List) {
        throw const ServerException('Unexpected warehouse list response.');
      }
      return raw.cast<String>();
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
