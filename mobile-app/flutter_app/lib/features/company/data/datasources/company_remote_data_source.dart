import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/company_model.dart';

abstract class CompanyRemoteDataSource {
  Future<List<CompanyModel>> listCompanies({int limit = 50});
}

class CompanyRemoteDataSourceImpl implements CompanyRemoteDataSource {
  final Dio dio;
  CompanyRemoteDataSourceImpl(this.dio);

  @override
  Future<List<CompanyModel>> listCompanies({int limit = 50}) async {
    final body = await _call(
      '/api/method/bude_api.api.companies.list_companies',
      queryParameters: {'limit': limit},
    );
    final list = (body['data'] as List).cast<Map<String, dynamic>>();
    return list.map(CompanyModel.fromJson).toList();
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
