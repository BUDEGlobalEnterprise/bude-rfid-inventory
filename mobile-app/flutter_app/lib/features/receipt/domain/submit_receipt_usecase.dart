import '../../../core/sync/pending_operation.dart';
import '../../../core/sync/sync_queue.dart';
import '../data/receipt_op_submitter.dart';
import 'receipt_draft.dart';

class SubmitReceiptUseCase {
  final SyncQueue queue;
  SubmitReceiptUseCase(this.queue);

  Future<String> call(ReceiptDraft draft) => callWithStatus(
        draft,
        OpStatus.pending,
      );

  Future<String> callWithStatus(
    ReceiptDraft draft,
    OpStatus initialStatus, {
    Map<String, dynamic> extraPayload = const {},
  }) {
    return queue.enqueue(
      type: kStockReceiptOpType,
      payload: {
        ...draft.toPayload(),
        ...extraPayload,
      },
      initialStatus: initialStatus,
    );
  }
}
