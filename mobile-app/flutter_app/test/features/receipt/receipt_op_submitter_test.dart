import 'package:bude_inventory/core/sync/op_submitter.dart';
import 'package:bude_inventory/core/sync/pending_operation.dart';
import 'package:bude_inventory/features/receipt/data/receipt_op_submitter.dart';
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
  late ReceiptOpSubmitter submitter;

  setUp(() {
    dio = _MockDio();
    submitter = ReceiptOpSubmitter(dio);
  });

  PendingOperation op() => PendingOperation(
        id: 'op-1',
        type: kStockReceiptOpType,
        payload: const {
          'target_warehouse': 'Tgt - X',
          'items': [
            {'item_code': 'A', 'qty': 1},
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

  test('type matches kStockReceiptOpType', () {
    expect(submitter.type, kStockReceiptOpType);
  });

  test('SubmitSuccess on Material Receipt name', () async {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer(
      (_) async => resp({
        'message': {
          'ok': true,
          'data': {'name': 'MAT-REC-2026-00007', 'docstatus': 1},
        },
      }),
    );

    final result = await submitter.submit(op());
    expect((result as SubmitSuccess).serverRef, 'MAT-REC-2026-00007');
  });

  test('VALIDATION_PO_LINE_MISMATCH → SubmitFatal', () async {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer(
      (_) async => resp({
        'message': {
          'ok': false,
          'code': 'VALIDATION_PO_LINE_MISMATCH',
          'message': 'Item(s) not on PO PO-001: B',
        },
      }),
    );

    final result = await submitter.submit(op());
    expect(result, isA<SubmitFatal>());
    expect((result as SubmitFatal).error, contains('PO-001'));
  });

  test('5xx → SubmitRetryable', () async {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenThrow(dioErr(status: 502));

    final result = await submitter.submit(op());
    expect(result, isA<SubmitRetryable>());
  });

  test('4xx (non-408/429) → SubmitFatal', () async {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenThrow(dioErr(status: 400));

    final result = await submitter.submit(op());
    expect(result, isA<SubmitFatal>());
  });

  test('connection error → SubmitRetryable', () async {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenThrow(dioErr(type: DioExceptionType.connectionError));

    final result = await submitter.submit(op());
    expect(result, isA<SubmitRetryable>());
  });
}
