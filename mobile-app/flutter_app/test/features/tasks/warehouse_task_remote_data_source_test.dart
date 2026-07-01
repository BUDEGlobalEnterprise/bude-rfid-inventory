import 'package:bude_inventory/core/errors/exceptions.dart';
import 'package:bude_inventory/features/tasks/data/warehouse_task_remote_data_source.dart';
import 'package:bude_inventory/features/tasks/domain/warehouse_task.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late WarehouseTaskRemoteDataSource dataSource;

  setUp(() {
    dio = _MockDio();
    dataSource = WarehouseTaskRemoteDataSource(dio);
  });

  Response<Map<String, dynamic>> response(Object? data) => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: {
          'message': {
            'ok': true,
            'data': data,
          },
        },
      );

  test('listOpen maps normalized task rows and passes company', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => response([
        {
          'id': 'TODO-PO',
          'kind': 'receivePurchaseOrder',
          'title': 'Receive PO-001',
          'subtitle': 'Acme',
          'priority': 'High',
          'due_date': '2026-07-02',
          'assigned_to': 'receiver@example.com',
          'company': 'Company A',
          'source_doctype': 'Purchase Order',
          'source_name': 'PO-001',
          'todo_name': 'TODO-PO',
          'item_count': 2,
          'pending_qty': 4,
        },
      ]),
    );

    final tasks = await dataSource.listOpen(company: 'Company A', limit: 25);

    expect(tasks, hasLength(1));
    expect(tasks.single.kind, WarehouseTaskKind.receivePurchaseOrder);
    expect(tasks.single.todoName, 'TODO-PO');
    expect(tasks.single.pendingQty, 4);
    final captured = verify(
      () => dio.get<Map<String, dynamic>>(
        '/api/method/bude_api.api.warehouse_tasks.list_open',
        queryParameters: captureAny(named: 'queryParameters'),
      ),
    ).captured.single as Map<String, dynamic>;
    expect(captured, {'limit': 25, 'company': 'Company A'});
  });

  test('complete posts todo and result metadata', () async {
    when(
      () => dio.post<Map<String, dynamic>>(
        any(),
        data: any(named: 'data'),
      ),
    ).thenAnswer((_) async => response({'name': 'TODO-PO'}));

    await dataSource.complete(
      todoName: ' TODO-PO ',
      resultDoctype: 'Purchase Receipt',
      resultName: 'PREC-001',
    );

    final captured = verify(
      () => dio.post<Map<String, dynamic>>(
        '/api/method/bude_api.api.warehouse_tasks.complete',
        data: captureAny(named: 'data'),
      ),
    ).captured.single as Map<String, dynamic>;
    expect(captured, {
      'todo_name': 'TODO-PO',
      'result_doctype': 'Purchase Receipt',
      'result_name': 'PREC-001',
    });
  });

  test('server envelope errors map to ServerException', () async {
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
            'message': 'No permission.',
            'code': 'PERMISSION_DENIED',
          },
        },
      ),
    );

    expect(dataSource.listOpen(), throwsA(isA<ServerException>()));
  });
}
