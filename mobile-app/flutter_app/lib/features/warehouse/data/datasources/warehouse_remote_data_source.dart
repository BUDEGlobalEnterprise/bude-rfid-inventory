import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/warehouse_stock_line_model.dart';

abstract class WarehouseRemoteDataSource {
  Future<List<String>> listWarehouses({int limit = 100});
  Future<List<WarehouseStockLineModel>> getStock(
    String warehouse, {
    int limit = 100,
  });
}

class WarehouseRemoteDataSourceImpl implements WarehouseRemoteDataSource {
  final Dio dio;
  WarehouseRemoteDataSourceImpl(this.dio);

  @override
  Future<List<String>> listWarehouses({int limit = 100}) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/method/bude_api.api.warehouses.list',
        queryParameters: {'limit': limit},
      );
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
      _mapDioException(e);
    }
  }

  @override
  Future<List<WarehouseStockLineModel>> getStock(
    String warehouse, {
    int limit = 100,
  }) async {
    final body = await _call(
      '/api/method/bude_api.api.warehouses.get_stock',
      queryParameters: {'warehouse': warehouse, 'limit': limit},
    );
    final list = (body['data'] as List).cast<Map<String, dynamic>>();
    return list.map(WarehouseStockLineModel.fromJson).toList();
  }

  Future<Map<String, dynamic>> _call(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
      );
      final envelope = response.data?['message'];
      if (envelope is! Map) {
        throw const ServerException('Unexpected response shape from server.');
      }
      final body = envelope.cast<String, dynamic>();
      if (body['ok'] != true) {
        final message = body['message'] as String? ?? 'Request failed.';
        final code = body['code'] as String?;
        if (code == 'VALIDATION_REQUIRED') {
          throw ValidationException(message);
        }
        throw ServerException(message);
      }
      return body;
    } on DioException catch (e) {
      _mapDioException(e);
    }
  }

  Never _mapDioException(DioException e) {
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

class ValidationException implements Exception {
  final String message;
  const ValidationException(this.message);
}
