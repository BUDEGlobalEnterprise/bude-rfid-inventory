import 'package:dio/dio.dart';

import '../../../core/errors/exceptions.dart';

class AssetKpis {
  final int totalAssets;
  final num totalValue;
  final int inMaintenance;
  final int upcomingMaintenance;

  const AssetKpis({
    required this.totalAssets,
    required this.totalValue,
    required this.inMaintenance,
    required this.upcomingMaintenance,
  });

  Map<String, dynamic> toJson() => {
        'total_assets': totalAssets,
        'total_value': totalValue,
        'in_maintenance': inMaintenance,
        'upcoming_maintenance': upcomingMaintenance,
      };

  factory AssetKpis.fromJson(Map<String, dynamic> j) => AssetKpis(
        totalAssets: (j['total_assets'] as num?)?.toInt() ?? 0,
        totalValue: (j['total_value'] as num?) ?? 0,
        inMaintenance: (j['in_maintenance'] as num?)?.toInt() ?? 0,
        upcomingMaintenance: (j['upcoming_maintenance'] as num?)?.toInt() ?? 0,
      );
}

class MaintenanceEntry {
  final String type; // 'maintenance' | 'repair'
  final String name;
  final String? asset;
  final String title;
  final String? status;
  final String date;
  final num? cost;

  const MaintenanceEntry({
    required this.type,
    required this.name,
    this.asset,
    required this.title,
    this.status,
    required this.date,
    this.cost,
  });

  factory MaintenanceEntry.fromJson(Map<String, dynamic> j) => MaintenanceEntry(
        type: j['type'] as String? ?? '',
        name: j['name'] as String? ?? '',
        asset: j['asset'] as String?,
        title: j['title'] as String? ?? '',
        status: j['status'] as String?,
        date: j['date'] as String? ?? '',
        cost: j['cost'] as num?,
      );
}

class ReportsRemoteDataSource {
  final Dio dio;
  ReportsRemoteDataSource(this.dio);

  Future<AssetKpis> summary() async {
    final body = await _call('bude_api.api.reports.asset_summary', {});
    return AssetKpis.fromJson((body['data'] as Map).cast<String, dynamic>());
  }

  /// Raw register rows (list of maps) — used directly for CSV export.
  Future<List<Map<String, dynamic>>> register() async {
    final body = await _call('bude_api.api.reports.asset_register', {});
    return (body['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<List<MaintenanceEntry>> maintenanceHistory({String? asset}) async {
    final body = await _call(
      'bude_api.api.reports.maintenance_history',
      {if (asset != null) 'asset': asset},
    );
    return (body['data'] as List)
        .cast<Map<String, dynamic>>()
        .map(MaintenanceEntry.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> _call(
    String method,
    Map<String, dynamic> params,
  ) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/method/$method',
        queryParameters: params,
      );
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
        e.type == DioExceptionType.receiveTimeout) {
      throw NetworkException(e.message ?? 'Network unreachable.');
    }
    throw ServerException(e.message ?? 'Server error.', statusCode: status);
  }
}
