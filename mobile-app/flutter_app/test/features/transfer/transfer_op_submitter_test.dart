import 'package:bude_inventory/core/sync/op_submitter.dart';
import 'package:bude_inventory/core/sync/pending_operation.dart';
import 'package:bude_inventory/features/transfer/data/transfer_op_submitter.dart';
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
  late TransferOpSubmitter submitter;

  setUp(() {
    dio = _MockDio();
    submitter = TransferOpSubmitter(dio);
  });

  PendingOperation op() => PendingOperation(
        id: 'op-1',
        type: kStockTransferOpType,
        payload: const {
          'source_warehouse': 'Src - X',
          'target_warehouse': 'Tgt - X',
          'items': [
            {'item_code': 'A', 'qty': 1},
          ],
        },
        status: OpStatus.pending,
        createdAt: DateTime.utc(2026, 6, 3),
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

  test('type matches the constant kStockTransferOpType', () {
    expect(submitter.type, kStockTransferOpType);
  });

  test('returns SubmitSuccess with server-assigned name on happy path',
      () async {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer(
      (_) async => resp({
        'message': {
          'ok': true,
          'data': {'name': 'STE-2026-00042', 'docstatus': 1},
        },
      }),
    );

    final result = await submitter.submit(op());

    expect(result, isA<SubmitSuccess>());
    expect((result as SubmitSuccess).serverRef, 'STE-2026-00042');
  });

  test('VALIDATION_* envelope is SubmitFatal (no retry)', () async {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer(
      (_) async => resp({
        'message': {
          'ok': false,
          'code': 'VALIDATION_UNKNOWN_WAREHOUSE',
          'message': 'Source warehouse does not exist.',
        },
      }),
    );

    final result = await submitter.submit(op());

    expect(result, isA<SubmitFatal>());
    expect((result as SubmitFatal).error, contains('Source warehouse'));
  });

  test('non-validation envelope failure is SubmitRetryable', () async {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer(
      (_) async => resp({
        'message': {
          'ok': false,
          'code': 'ENV_NO_FRAPPE',
          'message': 'Frappe not available.',
        },
      }),
    );

    final result = await submitter.submit(op());

    expect(result, isA<SubmitRetryable>());
  });

  test('4xx HTTP (other than 408/429) is SubmitFatal', () async {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenThrow(dioErr(status: 400));

    final result = await submitter.submit(op());
    expect(result, isA<SubmitFatal>());
  });

  test('5xx HTTP is SubmitRetryable', () async {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenThrow(dioErr(status: 503));

    final result = await submitter.submit(op());
    expect(result, isA<SubmitRetryable>());
  });

  test('429 rate-limit is SubmitRetryable', () async {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenThrow(dioErr(status: 429));

    final result = await submitter.submit(op());
    expect(result, isA<SubmitRetryable>());
  });

  test('connection error is SubmitRetryable', () async {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenThrow(dioErr(type: DioExceptionType.connectionError));

    final result = await submitter.submit(op());
    expect(result, isA<SubmitRetryable>());
  });

  test('malformed response shape is SubmitRetryable', () async {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer((_) async => resp({'unexpected': 'shape'}));

    final result = await submitter.submit(op());
    expect(result, isA<SubmitRetryable>());
  });
}
