import 'package:bude_inventory/core/errors/exceptions.dart';
import 'package:bude_inventory/features/fulfillment/data/sales_order_remote_data_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late SalesOrderRemoteDataSource dataSource;

  setUp(() {
    dio = _MockDio();
    dataSource = SalesOrderRemoteDataSource(dio);
  });

  Response<Map<String, dynamic>> response(Object data) => Response(
        requestOptions: RequestOptions(),
        statusCode: 200,
        data: {
          'message': {'ok': true, 'data': data},
        },
      );

  test('listOpen parses summaries and passes company', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => response([
        {
          'name': 'SO-001',
          'customer': 'Acme',
          'item_count': 2,
          'pending_qty': 3,
        },
      ]),
    );

    final orders = await dataSource.listOpen(company: 'Company A');

    expect(orders.single.name, 'SO-001');
    expect(orders.single.pendingQty, 3);
    final captured = verify(
      () => dio.get<Map<String, dynamic>>(
        '/api/method/bude_api.api.sales_orders.list_open',
        queryParameters: captureAny(named: 'queryParameters'),
      ),
    ).captured.single as Map<String, dynamic>;
    expect(captured['company'], 'Company A');
  });

  test('get parses detail lines', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => response({
        'name': 'SO-001',
        'customer': 'Acme',
        'items': [
          {
            'sales_order_item': 'SOI-1',
            'item_code': 'ITEM-1',
            'pending_qty': 2,
          },
        ],
      }),
    );

    final detail = await dataSource.get('SO-001');

    expect(detail.name, 'SO-001');
    expect(detail.items.single.salesOrderItem, 'SOI-1');
  });

  test('401 throws AuthException', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(),
        response: Response(requestOptions: RequestOptions(), statusCode: 401),
      ),
    );

    expect(dataSource.listOpen(), throwsA(isA<AuthException>()));
  });

  test('connection error throws NetworkException', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionError,
      ),
    );

    expect(dataSource.get('SO-001'), throwsA(isA<NetworkException>()));
  });
}
