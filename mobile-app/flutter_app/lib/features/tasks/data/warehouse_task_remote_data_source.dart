import 'package:dio/dio.dart';

import '../../../core/errors/exceptions.dart';
import '../domain/warehouse_task.dart';

class WarehouseTaskModel extends WarehouseTask {
  const WarehouseTaskModel({
    required super.id,
    required super.kind,
    required super.title,
    required super.subtitle,
    required super.priority,
    super.dueDate,
    super.assignedTo,
    super.company,
    required super.sourceDoctype,
    required super.sourceName,
    super.todoName,
    super.itemCount,
    super.pendingQty,
    super.assetName,
  });

  factory WarehouseTaskModel.fromJson(Map<String, dynamic> json) {
    return WarehouseTaskModel(
      id: json['id'] as String? ?? '',
      kind: warehouseTaskKindFromWire(json['kind'] as String? ?? ''),
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      priority: json['priority'] as String? ?? 'Medium',
      dueDate: json['due_date'] as String?,
      assignedTo: json['assigned_to'] as String?,
      company: json['company'] as String?,
      sourceDoctype: json['source_doctype'] as String? ?? '',
      sourceName: json['source_name'] as String? ?? '',
      todoName: json['todo_name'] as String?,
      itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
      pendingQty: (json['pending_qty'] as num?)?.toDouble() ?? 0,
      assetName: json['asset_name'] as String?,
    );
  }
}

class WarehouseTaskRemoteDataSource {
  final Dio dio;
  WarehouseTaskRemoteDataSource(this.dio);

  Future<List<WarehouseTask>> listOpen({
    int limit = 100,
    String? company,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (company != null && company.trim().isNotEmpty) {
      params['company'] = company.trim();
    }
    final body = await _request(
      () => dio.get<Map<String, dynamic>>(
        '/api/method/bude_api.api.warehouse_tasks.list_open',
        queryParameters: params,
      ),
      fallback: 'Failed to load warehouse tasks.',
    );
    final raw = body['data'];
    if (raw is! List) {
      throw const ServerException('Unexpected warehouse task response.');
    }
    return raw
        .cast<Map>()
        .map(
          (row) =>
              WarehouseTaskModel.fromJson(row.cast<String, dynamic>()),
        )
        .toList();
  }

  Future<void> complete({
    required String todoName,
    String? resultDoctype,
    String? resultName,
  }) async {
    final clean = todoName.trim();
    if (clean.isEmpty) return;
    await _request(
      () => dio.post<Map<String, dynamic>>(
        '/api/method/bude_api.api.warehouse_tasks.complete',
        data: {
          'todo_name': clean,
          if ((resultDoctype ?? '').trim().isNotEmpty)
            'result_doctype': resultDoctype!.trim(),
          if ((resultName ?? '').trim().isNotEmpty)
            'result_name': resultName!.trim(),
        },
      ),
      fallback: 'Failed to complete warehouse task.',
    );
  }

  Future<Map<String, dynamic>> _request(
    Future<Response<Map<String, dynamic>>> Function() send, {
    required String fallback,
  }) async {
    try {
      final response = await send();
      final envelope = response.data?['message'];
      if (envelope is! Map) {
        throw ServerException(fallback);
      }
      final body = envelope.cast<String, dynamic>();
      if (body['ok'] != true) {
        throw ServerException(body['message'] as String? ?? fallback);
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
