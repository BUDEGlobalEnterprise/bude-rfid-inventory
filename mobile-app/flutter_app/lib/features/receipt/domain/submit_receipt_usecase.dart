import '../../../core/sync/sync_queue.dart';
import '../data/receipt_op_submitter.dart';
import 'receipt_draft.dart';

class SubmitReceiptUseCase {
  final SyncQueue queue;
  SubmitReceiptUseCase(this.queue);

  Future<String> call(ReceiptDraft draft) {
    return queue.enqueue(
      type: kStockReceiptOpType,
      payload: draft.toPayload(),
    );
  }
}
