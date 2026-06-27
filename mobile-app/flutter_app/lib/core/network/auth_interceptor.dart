import 'package:dio/dio.dart';

typedef OnUnauthorized = Future<void> Function();

bool isUnauthorizedStatus(int? status) => status == 401 || status == 403;

class AuthInterceptor extends Interceptor {
  final OnUnauthorized onUnauthorized;

  AuthInterceptor({required this.onUnauthorized});

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final status = err.response?.statusCode;
    if (isUnauthorizedStatus(status)) {
      await onUnauthorized();
    }
    handler.next(err);
  }
}
