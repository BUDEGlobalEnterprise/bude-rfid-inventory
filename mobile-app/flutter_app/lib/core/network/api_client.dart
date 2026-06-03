import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'auth_interceptor.dart';

class ApiClient {
  final Dio _dio;

  ApiClient({Dio? dio}) : _dio = dio ?? _buildDefaultDio();

  static Dio _buildDefaultDio() {
    return Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  Dio get dio => _dio;

  void setBaseUrl(String baseUrl) {
    _dio.options.baseUrl = baseUrl;
  }

  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'token $token';
  }

  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  void installAuthInterceptor(AuthInterceptor interceptor) {
    _dio.interceptors.removeWhere((i) => i is AuthInterceptor);
    _dio.interceptors.add(interceptor);
  }
}
