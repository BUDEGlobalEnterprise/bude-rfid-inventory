import 'package:dio/dio.dart';

import '../../../core/sync/op_submitter.dart';
import '../../../core/sync/pending_operation.dart';

const String kSalesOrderDispatchOpType = 'sales_order_dispatch';

class SalesOrderDispatchOpSubmitter implements OpSubmitter {
  final Dio dio;
  SalesOrderDispatchOpSubmitter(this.dio);

  @override
  String get type => kSalesOrderDispatchOpType;

  @override
  Future<SubmitResult> submit(PendingOperation op) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/api/method/bude_api.api.sales_orders.create_delivery_note',
        data: op.payload,
      );
      final envelope = response.data?['message'];
      if (envelope is! Map) {
        return const SubmitRetryable('Unexpected response shape.');
      }
      final body = envelope.cast<String, dynamic>();
      if (body['ok'] == true) {
        final data = body['data'] as Map?;
        return SubmitSuccess((data?['name'] as String?) ?? '');
      }
      final code = body['code'] as String? ?? '';
      final message = body['message'] as String? ?? 'Server rejected dispatch.';
      if (code.startsWith('VALIDATION_')) return SubmitFatal(message);
      return SubmitRetryable(message);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status != null &&
          status >= 400 &&
          status < 500 &&
          status != 408 &&
          status != 429) {
        return SubmitFatal(e.message ?? 'HTTP $status');
      }
      return SubmitRetryable(e.message ?? 'Network error.');
    } catch (e) {
      return SubmitRetryable(e.toString());
    }
  }
}
