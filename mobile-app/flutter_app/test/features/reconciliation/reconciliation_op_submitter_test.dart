import 'package:bude_inventory/core/sync/op_submitter.dart';
import 'package:bude_inventory/core/sync/pending_operation.dart';
import 'package:bude_inventory/features/reconciliation/data/reconciliation_op_submitter.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

class _FakeRequestOptions extends Fake implements RequestOptions {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRequestOptions());
  });

  late _MockDio dio;
  late ReconciliationOpSubmitter submitter;

  setUp(() {
    dio = _MockDio();
    submitter = ReconciliationOpSubmitter(dio);
  });

  PendingOperation op() => PendingOperation(
        id: 'op-1',
        type: kStockReconciliationOpType,
        payload: const {
          'warehouse': 'Stores - X',
          'counts': [
            {'item_code': 'A', 'qty': 0},
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

  test('type is kStockReconciliationOpType', () {
    expect(submitter.type, kStockReconciliationOpType);
  });

  test('SubmitSuccess on ok=true with name', () async {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer(
      (_) async => resp({
        'message': {
          'ok': true,
          'data': {'name': 'RECON-2026-00001', 'docstatus': 1},
        },
      }),
    );

    final result = await submitter.submit(op());
    expect((result as SubmitSuccess).serverRef, 'RECON-2026-00001');
  });

  test('VALIDATION_UNKNOWN_ITEM → SubmitFatal', () async {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer(
      (_) async => resp({
        'message': {
          'ok': false,
          'code': 'VALIDATION_UNKNOWN_ITEM',
          'message': 'Unknown item(s): B',
        },
      }),
    );

    final result = await submitter.submit(op());
    expect(result, isA<SubmitFatal>());
  });

  test('5xx → SubmitRetryable', () async {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenThrow(dioErr(status: 500));

    final result = await submitter.submit(op());
    expect(result, isA<SubmitRetryable>());
  });

  test('connection timeout → SubmitRetryable', () async {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenThrow(dioErr(type: DioExceptionType.connectionTimeout));

    final result = await submitter.submit(op());
    expect(result, isA<SubmitRetryable>());
  });
}
