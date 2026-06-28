import 'package:dio/dio.dart';

import '../../../core/errors/exceptions.dart';

class BatchOption {
  final String batchNo;
  final String? expiryDate;

  const BatchOption({required this.batchNo, this.expiryDate});

  factory BatchOption.fromJson(Map<String, dynamic> json) {
    return BatchOption(
      batchNo: (json['batch_no'] ?? json['name'] ?? '').toString(),
      expiryDate: json['expiry_date']?.toString(),
    );
  }
}

class SerialOption {
  final String serialNo;
  final String? batchNo;
  final String? warehouse;

  const SerialOption({required this.serialNo, this.batchNo, this.warehouse});

  factory SerialOption.fromJson(Map<String, dynamic> json) {
    return SerialOption(
      serialNo: (json['name'] ?? '').toString(),
      batchNo: json['batch_no']?.toString(),
      warehouse: json['warehouse']?.toString(),
    );
  }
}

class TrackingRemoteDataSource {
  final Dio dio;
  TrackingRemoteDataSource(this.dio);

  Future<List<BatchOption>> batches(
    String itemCode, {
    String? warehouse,
    bool includeExpired = false,
  }) async {
    final body = await _call(
      '/api/method/bude_api.api.tracking.batches',
      {
        'item_code': itemCode,
        if (warehouse != null && warehouse.isNotEmpty) 'warehouse': warehouse,
        if (includeExpired) 'include_expired': '1',
      },
    );
    return (body['data'] as List)
        .cast<Map>()
        .map((raw) => BatchOption.fromJson(raw.cast<String, dynamic>()))
        .toList();
  }

  Future<List<SerialOption>> serials(
    String itemCode, {
    String? warehouse,
    String? batchNo,
  }) async {
    final body = await _call(
      '/api/method/bude_api.api.tracking.serials',
      {
        'item_code': itemCode,
        if (warehouse != null && warehouse.isNotEmpty) 'warehouse': warehouse,
        if (batchNo != null && batchNo.isNotEmpty) 'batch_no': batchNo,
      },
    );
    return (body['data'] as List)
        .cast<Map>()
        .map((raw) => SerialOption.fromJson(raw.cast<String, dynamic>()))
        .toList();
  }

  Future<Map<String, dynamic>> _call(
    String path,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(path, data: data);
      final envelope = response.data?['message'];
      if (envelope is! Map) {
        throw const ServerException('Unexpected response shape from server.');
      }
      final body = envelope.cast<String, dynamic>();
      if (body['ok'] != true) {
        throw ServerException(body['message'] as String? ?? 'Request failed.');
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
