import 'package:dio/dio.dart';

import '../../../core/errors/exceptions.dart';

class Alert {
  final String category;
  final String severity; // 'high' | 'medium'
  final String title;
  final String subtitle;
  final String refDoctype;
  final String refName;

  const Alert({
    required this.category,
    required this.severity,
    required this.title,
    required this.subtitle,
    required this.refDoctype,
    required this.refName,
  });

  factory Alert.fromJson(Map<String, dynamic> j) => Alert(
        category: j['category'] as String? ?? '',
        severity: j['severity'] as String? ?? 'medium',
        title: j['title'] as String? ?? '',
        subtitle: j['subtitle'] as String? ?? '',
        refDoctype: j['ref_doctype'] as String? ?? '',
        refName: j['ref_name'] as String? ?? '',
      );
}

class AlertsResult {
  final List<Alert> alerts;
  final int total;
  const AlertsResult({required this.alerts, required this.total});
}

class AlertsRemoteDataSource {
  final Dio dio;
  AlertsRemoteDataSource(this.dio);

  Future<AlertsResult> list() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/method/bude_api.api.alerts.list_alerts',
      );
      final envelope = response.data?['message'];
      if (envelope is! Map) {
        throw const ServerException('Unexpected response shape from server.');
      }
      final body = envelope.cast<String, dynamic>();
      if (body['ok'] != true) {
        throw ServerException(body['message'] as String? ?? 'Request failed.');
      }
      final data = (body['data'] as Map).cast<String, dynamic>();
      final alerts = (data['alerts'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(Alert.fromJson)
          .toList();
      return AlertsResult(alerts: alerts, total: (data['total'] as int?) ?? 0);
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
