import 'package:dio/dio.dart';

import '../../../core/errors/exceptions.dart';

/// Result of resolving a scanned EPC. Raw maps — a lookup result only needs a
/// few display fields, so full entity classes would be overkill.
/// ponytail: raw maps until a screen needs typed asset fields beyond display.
class ScanMatch {
  final String? matchType; // 'asset' | 'serial' | 'item' | null
  final Map<String, dynamic>? asset;
  final Map<String, dynamic>? serial;
  final Map<String, dynamic>? item;

  const ScanMatch({this.matchType, this.asset, this.serial, this.item});

  factory ScanMatch.fromJson(Map<String, dynamic> json) => ScanMatch(
        matchType: json['match_type'] as String?,
        asset: (json['asset'] as Map?)?.cast<String, dynamic>(),
        serial: (json['serial'] as Map?)?.cast<String, dynamic>(),
        item: (json['item'] as Map?)?.cast<String, dynamic>(),
      );

  bool get isUnregistered => matchType == null;
}

class EpcRemoteDataSource {
  final Dio dio;
  EpcRemoteDataSource(this.dio);

  Future<ScanMatch> resolve(String epc) async {
    final body = await _call(
      '/api/method/bude_api.api.scan.resolve_epc',
      {'epc': epc},
    );
    return ScanMatch.fromJson((body['data'] as Map).cast<String, dynamic>());
  }

  /// Bind an EPC to a standard record so future scans resolve to it.
  Future<void> bind(String doctype, String name, String epc) async {
    await _call(
      '/api/method/bude_api.api.assets.set_epc',
      {'doctype': doctype, 'name': name, 'epc': epc},
    );
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
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      throw const NetworkException(
        'Unable to connect. Check your network and try again.',
      );
    }
    if (e.type == DioExceptionType.unknown && e.error != null) {
      // Socket exceptions, DNS failures, etc. surface as "unknown" with a
      // nested error — these are almost always connectivity issues.
      throw const NetworkException(
        'Unable to connect. Check your network and try again.',
      );
    }
    throw ServerException(
      e.message ?? 'Something went wrong. Please try again.',
      statusCode: status,
    );
  }
}
