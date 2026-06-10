import 'package:dio/dio.dart';

import '../../../core/sync/op_submitter.dart';
import '../../../core/sync/pending_operation.dart';

const String kStockReceiptOpType = 'stock_receipt';

/// Drains queued stock_receipt ops by POSTing to
/// bude_api.api.stock.create_receipt. Classification follows the same rules
/// as TransferOpSubmitter: VALIDATION_* + 4xx → Fatal, 5xx/network/timeouts
/// → Retryable. On success, the server-assigned Stock Entry or Purchase
/// Receipt name becomes the op's serverRef.
class ReceiptOpSubmitter implements OpSubmitter {
  final Dio dio;
  ReceiptOpSubmitter(this.dio);

  @override
  String get type => kStockReceiptOpType;

  @override
  Future<SubmitResult> submit(PendingOperation op) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/api/method/bude_api.api.stock.create_receipt',
        data: op.payload,
      );
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
      final message = body['message'] as String? ?? 'Server rejected receipt.';
      if (code.startsWith('VALIDATION_')) {
        return SubmitFatal(message);
      }
      return SubmitRetryable(message);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status != null && status >= 400 && status < 500 && status != 408 && status != 429) {
        return SubmitFatal(e.message ?? 'HTTP $status');
      }
      return SubmitRetryable(e.message ?? 'Network error.');
    } catch (e) {
      return SubmitRetryable(e.toString());
    }
  }
}
