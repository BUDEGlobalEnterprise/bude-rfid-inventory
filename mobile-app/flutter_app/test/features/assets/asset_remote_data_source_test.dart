import 'package:bude_inventory/core/errors/exceptions.dart';
import 'package:bude_inventory/features/assets/data/asset_remote_data_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late AssetRemoteDataSource dataSource;

  setUp(() {
    dio = _MockDio();
    dataSource = AssetRemoteDataSource(dio);
  });

  Response<Map<String, dynamic>> response(Object? data) => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: {
          'message': {'ok': true, 'data': data},
        },
      );

  void whenGet(Object? data) {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => response(data));
  }

  test('listAssets sends only the provided filters and maps rows', () async {
    whenGet([
      {
        'name': 'AST-001',
        'asset_name': 'Forklift 1',
        'item_code': 'FORKLIFT',
        'asset_category': 'Vehicles',
        'location': 'Yard',
        'custodian': null,
        'status': 'Submitted',
        'gross_purchase_amount': 1000,
        'value_after_depreciation': 800,
        'bude_epc': 'EPC-001',
      },
    ]);

    final assets = await dataSource.listAssets(
      search: 'fork',
      status: 'Submitted',
    );

    expect(assets, hasLength(1));
    expect(assets.single.name, 'AST-001');
    expect(assets.single.assetName, 'Forklift 1');
    expect(assets.single.epc, 'EPC-001');

    final captured = verify(
      () => dio.get<Map<String, dynamic>>(
        '/api/method/bude_api.api.assets.list_assets',
        queryParameters: captureAny(named: 'queryParameters'),
      ),
    ).captured.single as Map<String, dynamic>;
    expect(captured, {'limit': 50, 'search': 'fork', 'status': 'Submitted'});
  });

  test('getAsset maps full detail including depreciation schedule', () async {
    whenGet({
      'name': 'AST-001',
      'asset_name': 'Forklift 1',
      'custodian_name': 'Jane Doe',
      'purchase_date': '2026-01-01',
      'available_for_use_date': '2026-01-05',
      'maintenance_required': true,
      'depreciation_schedule': [
        {
          'schedule_date': '2026-06-01',
          'depreciation_amount': 10,
          'accumulated_depreciation_amount': 10,
          'journal_entry': 'JV-001',
        },
      ],
    });

    final asset = await dataSource.getAsset('AST-001');

    expect(asset.custodianName, 'Jane Doe');
    expect(asset.maintenanceRequired, isTrue);
    expect(asset.depreciationSchedule, hasLength(1));
    expect(asset.depreciationSchedule.single.accumulated, 10);

    final captured = verify(
      () => dio.get<Map<String, dynamic>>(
        '/api/method/bude_api.api.assets.get_asset',
        queryParameters: captureAny(named: 'queryParameters'),
      ),
    ).captured.single as Map<String, dynamic>;
    expect(captured, {'name': 'AST-001'});
  });

  test('getMovements maps rows and defaults limit to 20', () async {
    whenGet([
      {
        'parent': 'MOV-001',
        'source_location': 'Stores',
        'target_location': 'Floor',
        'transaction_date': '2026-06-01',
        'purpose': 'Transfer',
      },
    ]);

    final moves = await dataSource.getMovements('AST-001');

    expect(moves.single.purpose, 'Transfer');
    final captured = verify(
      () => dio.get<Map<String, dynamic>>(
        '/api/method/bude_api.api.assets.get_asset_movements',
        queryParameters: captureAny(named: 'queryParameters'),
      ),
    ).captured.single as Map<String, dynamic>;
    expect(captured, {'asset': 'AST-001', 'limit': 20});
  });

  test('listLocations maps rows', () async {
    whenGet([
      {'name': 'Yard', 'location_name': 'Main Yard', 'is_group': false},
    ]);

    final locations = await dataSource.listLocations();

    expect(locations.single.name, 'Yard');
    final captured = verify(
      () => dio.get<Map<String, dynamic>>(
        '/api/method/bude_api.api.assets.list_locations',
        queryParameters: captureAny(named: 'queryParameters'),
      ),
    ).captured.single as Map<String, dynamic>;
    expect(captured, <String, dynamic>{});
  });

  test('listCategories returns a plain string list', () async {
    whenGet(['Vehicles', 'IT']);

    final categories = await dataSource.listCategories();

    expect(categories, ['Vehicles', 'IT']);
  });

  test('listMaintenanceLogs passes asset and hardcoded Planned status', () async {
    whenGet([
      {
        'name': 'LOG-001',
        'asset_name': 'AST-001',
        'task': 'Inspect belts',
        'maintenance_status': 'Planned',
        'due_date': '2026-07-10',
      },
    ]);

    final logs = await dataSource.listMaintenanceLogs('AST-001');

    expect(logs.single.name, 'LOG-001');
    final captured = verify(
      () => dio.get<Map<String, dynamic>>(
        '/api/method/bude_api.api.assets.list_maintenance_logs',
        queryParameters: captureAny(named: 'queryParameters'),
      ),
    ).captured.single as Map<String, dynamic>;
    expect(captured, {'asset': 'AST-001', 'status': 'Planned'});
  });

  test('401 response maps to AuthException', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ''),
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 401,
        ),
      ),
    );

    expect(dataSource.getAsset('AST-001'), throwsA(isA<AuthException>()));
  });

  test('connection error maps to NetworkException', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
      ),
    );

    expect(dataSource.getAsset('AST-001'), throwsA(isA<NetworkException>()));
  });

  test('unknown asset (ok:false envelope) maps to ServerException', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: {
          'message': {
            'ok': false,
            'message': "Asset 'AST-999' not found.",
            'code': 'VALIDATION_NOT_FOUND',
          },
        },
      ),
    );

    expect(
      dataSource.getAsset('AST-999'),
      throwsA(
        isA<ServerException>().having(
          (e) => e.message,
          'message',
          "Asset 'AST-999' not found.",
        ),
      ),
    );
  });

  test('other 5xx errors map to ServerException with status code', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ''),
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 502,
        ),
      ),
    );

    expect(
      dataSource.getAsset('AST-001'),
      throwsA(
        isA<ServerException>().having(
          (e) => e.statusCode,
          'statusCode',
          502,
        ),
      ),
    );
  });
}
