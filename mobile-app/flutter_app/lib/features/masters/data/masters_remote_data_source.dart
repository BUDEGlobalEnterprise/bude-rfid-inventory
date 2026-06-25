import 'package:dio/dio.dart';

import '../../../core/errors/exceptions.dart';
import '../domain/master_def.dart';

/// Online-only client for the generic master-data endpoints. Master edits are
/// low-frequency admin work, so (unlike operational ops) they are direct calls,
/// not queued through the offline sync engine.
class MastersRemoteDataSource {
  final Dio dio;
  MastersRemoteDataSource(this.dio);

  static const _base = '/api/method/bude_api.api.masters';

  Map<String, dynamic> _unwrap(Response<Map<String, dynamic>> res) {
    final envelope = res.data?['message']; // Frappe wraps returns under "message".
    if (envelope is! Map) {
      throw const ServerException('Unexpected masters response.');
    }
    final body = envelope.cast<String, dynamic>();
    if (body['ok'] != true) {
      throw ServerException((body['message'] as String?) ?? 'Request failed.');
    }
    return body;
  }

  Never _mapDio(DioException e) {
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

  Future<List<MasterDef>> listMasters() async {
    try {
      final res =
          await dio.get<Map<String, dynamic>>('$_base.list_masters');
      final data = _unwrap(res)['data'] as List;
      return data
          .map((e) => MasterDef.fromJson((e as Map).cast<String, dynamic>()))
          .toList(growable: false);
    } on DioException catch (e) {
      _mapDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> listRecords(
    String master, {
    String? search,
    int limit = 50,
  }) async {
    try {
      final res = await dio.get<Map<String, dynamic>>(
        '$_base.list_records',
        queryParameters: {
          'master': master,
          if (search != null && search.isNotEmpty) 'search': search,
          'limit': limit,
        },
      );
      final data = _unwrap(res)['data'] as List;
      return data
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList(growable: false);
    } on DioException catch (e) {
      _mapDio(e);
    }
  }

  Future<Map<String, dynamic>> getRecord(String master, String name) async {
    try {
      final res = await dio.get<Map<String, dynamic>>(
        '$_base.get_record',
        queryParameters: {'master': master, 'name': name},
      );
      return (_unwrap(res)['data'] as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      _mapDio(e);
    }
  }

  Future<List<String>> linkOptions(String doctype, {String? search}) async {
    try {
      final res = await dio.get<Map<String, dynamic>>(
        '$_base.list_link_options',
        queryParameters: {
          'doctype': doctype,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );
      final data = _unwrap(res)['data'] as List;
      return data.map((e) => e.toString()).toList(growable: false);
    } on DioException catch (e) {
      _mapDio(e);
    }
  }

  /// Returns the server-assigned record name.
  Future<String> create(String master, Map<String, dynamic> values) async {
    try {
      final res = await dio.post<Map<String, dynamic>>(
        '$_base.create_record',
        data: {'master': master, 'values': values},
      );
      final data = (_unwrap(res)['data'] as Map).cast<String, dynamic>();
      return data['name'] as String;
    } on DioException catch (e) {
      _mapDio(e);
    }
  }

  Future<void> update(
    String master,
    String name,
    Map<String, dynamic> values,
  ) async {
    try {
      final res = await dio.post<Map<String, dynamic>>(
        '$_base.update_record',
        data: {'master': master, 'name': name, 'values': values},
      );
      _unwrap(res);
    } on DioException catch (e) {
      _mapDio(e);
    }
  }

  Future<void> setDisabled(String master, String name, bool disabled) async {
    try {
      final res = await dio.post<Map<String, dynamic>>(
        '$_base.set_disabled',
        data: {'master': master, 'name': name, 'disabled': disabled},
      );
      _unwrap(res);
    } on DioException catch (e) {
      _mapDio(e);
    }
  }
}
