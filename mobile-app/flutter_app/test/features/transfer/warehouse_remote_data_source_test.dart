import 'package:bude_inventory/features/transfer/data/warehouse_remote_data_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late WarehouseRemoteDataSource dataSource;

  setUp(() {
    dio = _MockDio();
    dataSource = WarehouseRemoteDataSource(dio);
  });

  Response<Map<String, dynamic>> response() => Response(
        requestOptions: RequestOptions(),
        statusCode: 200,
        data: {
          'message': {
            'ok': true,
            'data': ['Stores - A'],
          },
        },
      );

  test('passes company when listing warehouses', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => response());

    final warehouses = await dataSource.list(company: 'Company A');

    expect(warehouses, ['Stores - A']);
    final captured = verify(
      () => dio.get<Map<String, dynamic>>(
        '/api/method/bude_api.api.warehouses.list',
        queryParameters: captureAny(named: 'queryParameters'),
      ),
    ).captured.single as Map<String, dynamic>;
    expect(captured, {'limit': 100, 'company': 'Company A'});
  });

  test('passes warehouse and company when listing locations', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => response());

    final locations = await dataSource.listLocations(
      'Stores - A',
      company: 'Company A',
    );

    expect(locations, ['Stores - A']);
    final captured = verify(
      () => dio.get<Map<String, dynamic>>(
        '/api/method/bude_api.api.warehouses.list_locations',
        queryParameters: captureAny(named: 'queryParameters'),
      ),
    ).captured.single as Map<String, dynamic>;
    expect(captured, {
      'warehouse': 'Stores - A',
      'limit': 100,
      'company': 'Company A',
    });
  });
}
