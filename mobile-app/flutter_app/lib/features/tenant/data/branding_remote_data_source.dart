import 'package:dio/dio.dart';

import '../../../core/errors/exceptions.dart';
import '../domain/branding.dart';

abstract class BrandingRemoteDataSource {
  Future<Branding> fetch();
}

class BrandingRemoteDataSourceImpl implements BrandingRemoteDataSource {
  final Dio dio;
  BrandingRemoteDataSourceImpl(this.dio);

  @override
  Future<Branding> fetch() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/method/bude_api.api.branding.get',
      );
      final body = response.data?['message'];
      if (body is! Map) {
        throw const ServerException('Unexpected branding response shape.');
      }
      final envelope = body.cast<String, dynamic>();
      if (envelope['ok'] != true) {
        throw ServerException(
          (envelope['message'] as String?) ?? 'Branding request failed.',
        );
      }
      final data = (envelope['data'] as Map).cast<String, dynamic>();
      return Branding.fromJson(data);
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
