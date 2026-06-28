import '../../../core/sync/sync_queue.dart';
import '../data/sales_order_dispatch_op_submitter.dart';
import 'fulfillment_draft.dart';

class SubmitSalesOrderDispatchUseCase {
  final SyncQueue queue;
  SubmitSalesOrderDispatchUseCase(this.queue);

  Future<String> call(FulfillmentDraft draft) {
    return queue.enqueue(
      type: kSalesOrderDispatchOpType,
      payload: draft.toPayload(),
    );
  }
}
