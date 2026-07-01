import 'package:bude_inventory/core/sync/op_submitter.dart';
import 'package:bude_inventory/core/sync/pending_operation.dart';
import 'package:bude_inventory/features/assets/data/asset_op_submitters.dart';
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

  setUp(() {
    dio = _MockDio();
  });

  PendingOperation op(String type, Map<String, dynamic> payload) =>
      PendingOperation(
        id: 'op-1',
        type: type,
        payload: payload,
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

  void whenPost(Response<Map<String, dynamic>> Function() answer) {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer((_) async => answer());
  }

  void whenPostThrows(DioException e) {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenThrow(e);
  }

  group('AssetMovementOpSubmitter', () {
    late AssetMovementOpSubmitter submitter;
    setUp(() => submitter = AssetMovementOpSubmitter(dio));

    test('type matches kAssetMovementOpType', () {
      expect(submitter.type, kAssetMovementOpType);
    });

    test('SubmitSuccess on Asset Movement name', () async {
      whenPost(() => resp({
            'message': {
              'ok': true,
              'data': {'name': 'MOV-2026-00001', 'docstatus': 1},
            },
          }));

      final result = await submitter.submit(
        op(kAssetMovementOpType, {
          'assets': ['AST-001'],
          'purpose': 'Transfer',
          'target_location': 'Floor',
        }),
      );

      expect((result as SubmitSuccess).serverRef, 'MOV-2026-00001');
    });

    test('VALIDATION_NOT_FOUND → SubmitFatal', () async {
      whenPost(() => resp({
            'message': {
              'ok': false,
              'code': 'VALIDATION_NOT_FOUND',
              'message': "Asset 'AST-999' not found.",
            },
          }));

      final result = await submitter.submit(
        op(kAssetMovementOpType, {'assets': ['AST-999'], 'purpose': 'Transfer'}),
      );

      expect(result, isA<SubmitFatal>());
      expect((result as SubmitFatal).error, contains('AST-999'));
    });

    test('5xx → SubmitRetryable', () async {
      whenPostThrows(dioErr(status: 502));

      final result = await submitter.submit(
        op(kAssetMovementOpType, const {}),
      );

      expect(result, isA<SubmitRetryable>());
    });

    test('4xx (non-408/429) → SubmitFatal', () async {
      whenPostThrows(dioErr(status: 400));

      final result = await submitter.submit(
        op(kAssetMovementOpType, const {}),
      );

      expect(result, isA<SubmitFatal>());
    });

    test('connection error → SubmitRetryable', () async {
      whenPostThrows(dioErr(type: DioExceptionType.connectionError));

      final result = await submitter.submit(
        op(kAssetMovementOpType, const {}),
      );

      expect(result, isA<SubmitRetryable>());
    });
  });

  group('AssetRepairOpSubmitter', () {
    late AssetRepairOpSubmitter submitter;
    setUp(() => submitter = AssetRepairOpSubmitter(dio));

    test('type matches kAssetRepairOpType', () {
      expect(submitter.type, kAssetRepairOpType);
    });

    test('SubmitSuccess on Asset Repair name', () async {
      whenPost(() => resp({
            'message': {
              'ok': true,
              'data': {'name': 'ASSET-REPAIR-00001', 'docstatus': 0},
            },
          }));

      final result = await submitter.submit(
        op(kAssetRepairOpType, {'asset': 'AST-001'}),
      );

      expect((result as SubmitSuccess).serverRef, 'ASSET-REPAIR-00001');
    });

    test('VALIDATION_* → SubmitFatal', () async {
      whenPost(() => resp({
            'message': {
              'ok': false,
              'code': 'VALIDATION_REQUIRED',
              'message': 'asset is required.',
            },
          }));

      final result = await submitter.submit(
        op(kAssetRepairOpType, const {}),
      );

      expect(result, isA<SubmitFatal>());
    });

    test('408 → SubmitRetryable', () async {
      whenPostThrows(dioErr(status: 408));

      final result = await submitter.submit(
        op(kAssetRepairOpType, const {}),
      );

      expect(result, isA<SubmitRetryable>());
    });

    test('unexpected response shape → SubmitRetryable', () async {
      whenPost(() => resp({'message': 'not a map'}));

      final result = await submitter.submit(
        op(kAssetRepairOpType, const {}),
      );

      expect(result, isA<SubmitRetryable>());
    });
  });

  group('MaintenanceLogOpSubmitter', () {
    late MaintenanceLogOpSubmitter submitter;
    setUp(() => submitter = MaintenanceLogOpSubmitter(dio));

    test('type matches kMaintenanceLogOpType', () {
      expect(submitter.type, kMaintenanceLogOpType);
    });

    test('SubmitSuccess on completed log name', () async {
      whenPost(() => resp({
            'message': {
              'ok': true,
              'data': {'name': 'LOG-001', 'maintenance_status': 'Completed'},
            },
          }));

      final result = await submitter.submit(
        op(kMaintenanceLogOpType, {'log': 'LOG-001'}),
      );

      expect((result as SubmitSuccess).serverRef, 'LOG-001');
    });

    test('VALIDATION_NOT_FOUND → SubmitFatal', () async {
      whenPost(() => resp({
            'message': {
              'ok': false,
              'code': 'VALIDATION_NOT_FOUND',
              'message': "Maintenance log 'LOG-999' not found.",
            },
          }));

      final result = await submitter.submit(
        op(kMaintenanceLogOpType, {'log': 'LOG-999'}),
      );

      expect(result, isA<SubmitFatal>());
    });

    test('429 → SubmitRetryable', () async {
      whenPostThrows(dioErr(status: 429));

      final result = await submitter.submit(
        op(kMaintenanceLogOpType, {'log': 'LOG-001'}),
      );

      expect(result, isA<SubmitRetryable>());
    });
  });
}
