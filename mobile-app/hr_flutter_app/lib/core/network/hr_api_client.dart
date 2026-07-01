import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_session_store.dart';

final hrApiClientProvider = Provider<HrApiClient>((ref) {
  return HrApiClient(ref.watch(secureSessionStoreProvider));
});

class HrApiClient {
  HrApiClient(this._sessionStore, {Dio? dio}) : _dio = dio ?? Dio();

  final SecureSessionStore _sessionStore;
  final Dio _dio;

  Future<Map<String, dynamic>> get(
    String baseUrl,
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final response = await _dio.getUri(
      Uri.parse(baseUrl).replace(path: path, queryParameters: query),
      options: await _options(),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> post(
    String baseUrl,
    String path, {
    Map<String, dynamic>? data,
  }) async {
    final response = await _dio.postUri(
      Uri.parse(baseUrl).replace(path: path),
      data: data,
      options: await _options(),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Options> _options() async {
    final session = await _sessionStore.read();
    final headers = <String, String>{};
    if (session?.apiKey != null && session?.apiSecret != null) {
      headers['Authorization'] =
          'token ${session!.apiKey}:${session.apiSecret}';
    }
    return Options(headers: headers);
  }
}
