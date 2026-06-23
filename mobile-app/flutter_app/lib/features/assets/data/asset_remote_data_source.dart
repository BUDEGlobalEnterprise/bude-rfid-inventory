import 'package:dio/dio.dart';

import '../../../core/errors/exceptions.dart';

// ── Models (lightweight; read-mostly feature) ─────────────────────────────────

class AssetSummary {
  final String name;
  final String assetName;
  final String? itemCode;
  final String? category;
  final String? location;
  final String? custodian;
  final String? status;
  final num? grossPurchaseAmount;
  final num? valueAfterDepreciation;
  final String? epc;

  const AssetSummary({
    required this.name,
    required this.assetName,
    this.itemCode,
    this.category,
    this.location,
    this.custodian,
    this.status,
    this.grossPurchaseAmount,
    this.valueAfterDepreciation,
    this.epc,
  });

  factory AssetSummary.fromJson(Map<String, dynamic> j) => AssetSummary(
        name: j['name'] as String,
        assetName: (j['asset_name'] ?? j['name']) as String,
        itemCode: j['item_code'] as String?,
        category: j['asset_category'] as String?,
        location: j['location'] as String?,
        custodian: j['custodian'] as String?,
        status: j['status'] as String?,
        grossPurchaseAmount: j['gross_purchase_amount'] as num?,
        valueAfterDepreciation: j['value_after_depreciation'] as num?,
        epc: j['bude_epc'] as String?,
      );
}

class DepreciationRow {
  final String scheduleDate;
  final num? depreciationAmount;
  final num? accumulated;
  final String? journalEntry;

  const DepreciationRow({
    required this.scheduleDate,
    this.depreciationAmount,
    this.accumulated,
    this.journalEntry,
  });

  factory DepreciationRow.fromJson(Map<String, dynamic> j) => DepreciationRow(
        scheduleDate: (j['schedule_date'] ?? '') as String,
        depreciationAmount: j['depreciation_amount'] as num?,
        accumulated: j['accumulated_depreciation_amount'] as num?,
        journalEntry: j['journal_entry'] as String?,
      );
}

class AssetDetail {
  final String name;
  final String assetName;
  final String? itemCode;
  final String? category;
  final String? company;
  final String? status;
  final String? location;
  final String? custodian;
  final String? custodianName;
  final String purchaseDate;
  final String availableForUseDate;
  final num? grossPurchaseAmount;
  final num? valueAfterDepreciation;
  final bool maintenanceRequired;
  final String? epc;
  final List<DepreciationRow> depreciationSchedule;

  const AssetDetail({
    required this.name,
    required this.assetName,
    this.itemCode,
    this.category,
    this.company,
    this.status,
    this.location,
    this.custodian,
    this.custodianName,
    required this.purchaseDate,
    required this.availableForUseDate,
    this.grossPurchaseAmount,
    this.valueAfterDepreciation,
    this.maintenanceRequired = false,
    this.epc,
    this.depreciationSchedule = const [],
  });

  factory AssetDetail.fromJson(Map<String, dynamic> j) => AssetDetail(
        name: j['name'] as String,
        assetName: (j['asset_name'] ?? j['name']) as String,
        itemCode: j['item_code'] as String?,
        category: j['asset_category'] as String?,
        company: j['company'] as String?,
        status: j['status'] as String?,
        location: j['location'] as String?,
        custodian: j['custodian'] as String?,
        custodianName: j['custodian_name'] as String?,
        purchaseDate: (j['purchase_date'] ?? '') as String,
        availableForUseDate: (j['available_for_use_date'] ?? '') as String,
        grossPurchaseAmount: j['gross_purchase_amount'] as num?,
        valueAfterDepreciation: j['value_after_depreciation'] as num?,
        maintenanceRequired:
            j['maintenance_required'] == 1 || j['maintenance_required'] == true,
        epc: j['bude_epc'] as String?,
        depreciationSchedule: ((j['depreciation_schedule'] as List?) ?? [])
            .map(
              (e) =>
                  DepreciationRow.fromJson((e as Map).cast<String, dynamic>()),
            )
            .toList(),
      );
}

class AssetMovementRow {
  final String parent;
  final String? sourceLocation;
  final String? targetLocation;
  final String? fromEmployee;
  final String? toEmployee;
  final String transactionDate;
  final String? purpose;

  const AssetMovementRow({
    required this.parent,
    this.sourceLocation,
    this.targetLocation,
    this.fromEmployee,
    this.toEmployee,
    required this.transactionDate,
    this.purpose,
  });

  factory AssetMovementRow.fromJson(Map<String, dynamic> j) => AssetMovementRow(
        parent: j['parent'] as String,
        sourceLocation: j['source_location'] as String?,
        targetLocation: j['target_location'] as String?,
        fromEmployee: j['from_employee'] as String?,
        toEmployee: j['to_employee'] as String?,
        transactionDate: (j['transaction_date'] ?? '') as String,
        purpose: j['purpose'] as String?,
      );
}

class AssetLocation {
  final String name;
  final String? locationName;
  final num? latitude;
  final num? longitude;
  final bool isGroup;

  const AssetLocation({
    required this.name,
    this.locationName,
    this.latitude,
    this.longitude,
    this.isGroup = false,
  });

  factory AssetLocation.fromJson(Map<String, dynamic> j) => AssetLocation(
        name: j['name'] as String,
        locationName: j['location_name'] as String?,
        latitude: j['latitude'] as num?,
        longitude: j['longitude'] as num?,
        isGroup: j['is_group'] == 1 || j['is_group'] == true,
      );
}

class MaintenanceLog {
  final String name;
  final String? assetName;
  final String? task;
  final String? status;
  final String dueDate;

  const MaintenanceLog({
    required this.name,
    this.assetName,
    this.task,
    this.status,
    required this.dueDate,
  });

  factory MaintenanceLog.fromJson(Map<String, dynamic> j) => MaintenanceLog(
        name: j['name'] as String,
        assetName: j['asset_name'] as String?,
        task: j['task'] as String?,
        status: j['maintenance_status'] as String?,
        dueDate: (j['due_date'] ?? '') as String,
      );
}

// ── Data source ───────────────────────────────────────────────────────────────

class AssetRemoteDataSource {
  final Dio dio;
  AssetRemoteDataSource(this.dio);

  Future<List<MaintenanceLog>> listMaintenanceLogs(String asset) async {
    final body = await _call(
      'bude_api.api.assets.list_maintenance_logs',
      {'asset': asset, 'status': 'Planned'},
    );
    return (body['data'] as List)
        .cast<Map<String, dynamic>>()
        .map(MaintenanceLog.fromJson)
        .toList();
  }

  Future<List<AssetSummary>> listAssets({
    String? search,
    String? location,
    String? custodian,
    String? status,
    String? category,
    int limit = 50,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (location != null) params['location'] = location;
    if (custodian != null) params['custodian'] = custodian;
    if (status != null) params['status'] = status;
    if (category != null) params['category'] = category;
    final body = await _call('bude_api.api.assets.list_assets', params);
    return (body['data'] as List)
        .cast<Map<String, dynamic>>()
        .map(AssetSummary.fromJson)
        .toList();
  }

  Future<AssetDetail> getAsset(String name) async {
    final body = await _call('bude_api.api.assets.get_asset', {'name': name});
    return AssetDetail.fromJson((body['data'] as Map).cast<String, dynamic>());
  }

  Future<List<AssetMovementRow>> getMovements(
    String asset, {
    int limit = 20,
  }) async {
    final body = await _call(
      'bude_api.api.assets.get_asset_movements',
      {'asset': asset, 'limit': limit},
    );
    return (body['data'] as List)
        .cast<Map<String, dynamic>>()
        .map(AssetMovementRow.fromJson)
        .toList();
  }

  Future<List<AssetLocation>> listLocations() async {
    final body = await _call('bude_api.api.assets.list_locations', {});
    return (body['data'] as List)
        .cast<Map<String, dynamic>>()
        .map(AssetLocation.fromJson)
        .toList();
  }

  Future<List<String>> listCategories() async {
    final body = await _call('bude_api.api.assets.list_asset_categories', {});
    return (body['data'] as List).cast<String>();
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
