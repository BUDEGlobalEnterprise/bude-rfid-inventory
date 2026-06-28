import 'package:dio/dio.dart';

import '../../../core/errors/exceptions.dart';
import 'sales_order_models.dart';

class SalesOrderRemoteDataSource {
  final Dio dio;
  SalesOrderRemoteDataSource(this.dio);

  Future<List<SalesOrderSummaryModel>> listOpen({
    int limit = 50,
    String? company,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (company != null && company.trim().isNotEmpty) {
      params['company'] = company.trim();
    }
    final body = await _get(
      '/api/method/bude_api.api.sales_orders.list_open',
      queryParameters: params,
      unexpected: 'Unexpected Sales Order list response.',
    );
    final raw = body['data'];
    if (raw is! List) {
      throw const ServerException('Unexpected Sales Order list response.');
    }
    return raw
        .cast<Map>()
        .map(
          (row) => SalesOrderSummaryModel.fromJson(row.cast<String, dynamic>()),
        )
        .toList();
  }

  Future<SalesOrderDetailModel> get(String name) async {
    final body = await _get(
      '/api/method/bude_api.api.sales_orders.get',
      queryParameters: {'name': name},
      unexpected: 'Unexpected Sales Order detail response.',
    );
    final raw = body['data'];
    if (raw is! Map) {
      throw const ServerException('Unexpected Sales Order detail response.');
    }
    return SalesOrderDetailModel.fromJson(raw.cast<String, dynamic>());
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    required Map<String, dynamic> queryParameters,
    required String unexpected,
  }) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
      );
      final envelope = response.data?['message'];
      if (envelope is! Map) throw ServerException(unexpected);
      final body = envelope.cast<String, dynamic>();
      if (body['ok'] != true) {
        throw ServerException(
          (body['message'] as String?) ?? 'Failed to load Sales Orders.',
        );
      }
      return body;
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
