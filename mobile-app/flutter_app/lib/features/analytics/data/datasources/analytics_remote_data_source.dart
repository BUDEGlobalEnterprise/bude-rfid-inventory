import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/reconciliation_summary_model.dart';
import '../models/stock_aging_row_model.dart';

abstract class AnalyticsRemoteDataSource {
  Future<List<StockAgingRowModel>> getStockAging(
    String warehouse, {
    int thresholdDays = 30,
    int limit = 100,
  });

  Future<List<ReconciliationSummaryModel>> getReconciliationHistory({
    String? warehouse,
    int limit = 20,
  });
}

class AnalyticsRemoteDataSourceImpl implements AnalyticsRemoteDataSource {
  final Dio dio;
  AnalyticsRemoteDataSourceImpl(this.dio);

  @override
  Future<List<StockAgingRowModel>> getStockAging(
    String warehouse, {
    int thresholdDays = 30,
    int limit = 100,
  }) async {
    final body = await _call(
      '/api/method/bude_api.api.analytics.get_stock_aging',
      queryParameters: {
        'warehouse': warehouse,
        'threshold_days': thresholdDays,
        'limit': limit,
      },
    );
    final list = (body['data'] as List).cast<Map<String, dynamic>>();
    return list.map(StockAgingRowModel.fromJson).toList();
  }

  @override
  Future<List<ReconciliationSummaryModel>> getReconciliationHistory({
    String? warehouse,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (warehouse != null) params['warehouse'] = warehouse;

    final body = await _call(
      '/api/method/bude_api.api.analytics.get_reconciliation_history',
      queryParameters: params,
    );
    final list = (body['data'] as List).cast<Map<String, dynamic>>();
    return list.map(ReconciliationSummaryModel.fromJson).toList();
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
        if (code == 'VALIDATION_REQUIRED' || code == 'VALIDATION_UNKNOWN_WAREHOUSE') {
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
