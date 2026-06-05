import 'package:dio/dio.dart';

import '../../../core/sync/op_submitter.dart';
import '../../../core/sync/pending_operation.dart';

/// Operation type string stored on every queued transfer. Must match what
/// SubmitTransferUseCase enqueues; centralized here so the two stay in sync.
const String kStockTransferOpType = 'stock_transfer';

/// Drains queued stock_transfer ops by POSTing to bude_api.api.stock.create_transfer.
/// 4xx VALIDATION_* responses are SubmitFatal (won't retry); 5xx / network are
/// SubmitRetryable (engine backs off). On success, the server-assigned Stock
/// Entry name (e.g. "STE-2026-00001") becomes the op's serverRef.
class TransferOpSubmitter implements OpSubmitter {
  final Dio dio;
  TransferOpSubmitter(this.dio);

  @override
  String get type => kStockTransferOpType;

  @override
  Future<SubmitResult> submit(PendingOperation op) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/api/method/bude_api.api.stock.create_transfer',
        data: op.payload,
      );
      // Frappe wraps method returns under "message".
      final envelope = response.data?['message'];
      if (envelope is! Map) {
        return const SubmitRetryable('Unexpected response shape.');
      }
      final body = envelope.cast<String, dynamic>();
      if (body['ok'] == true) {
        final data = body['data'] as Map?;
        final name = (data?['name'] as String?) ?? '';
        return SubmitSuccess(name);
      }
      final code = body['code'] as String? ?? '';
      final message = body['message'] as String? ?? 'Server rejected transfer.';
      if (code.startsWith('VALIDATION_')) {
        return SubmitFatal(message);
      }
      return SubmitRetryable(message);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status != null && status >= 400 && status < 500 && status != 408 && status != 429) {
        // 4xx (except timeouts / rate-limits) → permanent.
        return SubmitFatal(e.message ?? 'HTTP $status');
      }
      return SubmitRetryable(e.message ?? 'Network error.');
    } catch (e) {
      return SubmitRetryable(e.toString());
    }
  }
}
