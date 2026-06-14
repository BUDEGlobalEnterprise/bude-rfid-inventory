import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/auth_session_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthSessionModel> login({
    required String username,
    required String password,
  });

  Future<void> logout();

  Future<Map<String, dynamic>> sessionInfo();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;

  AuthRemoteDataSourceImpl(this.dio);

  @override
  Future<AuthSessionModel> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/api/method/bude_api.api.auth.login',
        data: {'usr': username, 'pwd': password},
      );

      // Frappe wraps every /api/method return value under "message".
      final body = _unwrapEnvelope(response.data);
      if (body['ok'] != true) {
        throw AuthException(
          (body['message'] as String?) ?? 'Login failed.',
        );
      }

      return AuthSessionModel.fromJson(
        (body['data'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await dio.post<dynamic>('/api/method/bude_api.api.auth.logout');
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> sessionInfo() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/method/bude_api.api.auth.session_info',
      );

      final body = _unwrapEnvelope(response.data);
      if (body['ok'] != true) {
        throw const AuthException('No active session.');
      }
      return (body['data'] as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Frappe wraps the return value of every /api/method/* call under a
  /// top-level "message" key. Returns the unwrapped bude_api envelope
  /// ({ok, data, message, code}).
  Map<String, dynamic> _unwrapEnvelope(Map<String, dynamic>? raw) {
    final envelope = raw?['message'];
    if (envelope is! Map) {
      throw const AuthException('Unexpected response shape from server.');
    }
    return envelope.cast<String, dynamic>();
  }

  Exception _mapDioError(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401 || status == 403) {
      return const AuthException('Authentication required.');
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.receiveTimeout) {
      return NetworkException(e.message ?? 'Network unreachable.');
    }
    return ServerException(
      e.message ?? 'Server error.',
      statusCode: status,
    );
  }
}
