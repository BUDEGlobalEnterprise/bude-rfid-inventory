import 'package:bude_inventory/core/sync/op_submitter.dart';
import 'package:bude_inventory/core/sync/pending_operation.dart';
import 'package:bude_inventory/features/fulfillment/data/sales_order_dispatch_op_submitter.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late SalesOrderDispatchOpSubmitter submitter;

  setUp(() {
    dio = _MockDio();
    submitter = SalesOrderDispatchOpSubmitter(dio);
  });

  PendingOperation op() => PendingOperation(
        id: 'op-1',
        type: kSalesOrderDispatchOpType,
        payload: const {
          'sales_order': 'SO-001',
          'source_warehouse': 'Stores - A',
          'items': [
            {'sales_order_item': 'SOI-1', 'item_code': 'ITEM-1', 'qty': 1},
          ],
        },
        status: OpStatus.pending,
        createdAt: DateTime.utc(2026, 6, 10),
      );

  Response<Map<String, dynamic>> resp(Map<String, dynamic> body) => Response(
        requestOptions: RequestOptions(),
        statusCode: 200,
        data: body,
      );

  DioException dioErr({int? status, DioExceptionType? type}) => DioException(
        requestOptions: RequestOptions(),
        type: type ?? DioExceptionType.unknown,
        response: status == null
            ? null
            : Response(requestOptions: RequestOptions(), statusCode: status),
      );

  test('SubmitSuccess on Delivery Note name', () async {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer(
      (_) async => resp({
        'message': {
          'ok': true,
          'data': {'name': 'DN-001'},
        },
      }),
    );

    final result = await submitter.submit(op());

    expect((result as SubmitSuccess).serverRef, 'DN-001');
  });

  test('VALIDATION_EXACT_QTY_REQUIRED is fatal', () async {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer(
      (_) async => resp({
        'message': {
          'ok': false,
          'code': 'VALIDATION_EXACT_QTY_REQUIRED',
          'message': 'Exact qty required',
        },
      }),
    );

    expect(await submitter.submit(op()), isA<SubmitFatal>());
  });

  test('5xx is retryable and 4xx is fatal', () async {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenThrow(dioErr(status: 502));
    expect(await submitter.submit(op()), isA<SubmitRetryable>());

    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenThrow(dioErr(status: 400));
    expect(await submitter.submit(op()), isA<SubmitFatal>());
  });

  test('connection error is retryable', () async {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenThrow(dioErr(type: DioExceptionType.connectionError));

    expect(await submitter.submit(op()), isA<SubmitRetryable>());
  });
}
