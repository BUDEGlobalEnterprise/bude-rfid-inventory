import '../../../core/sync/pending_operation.dart';
import '../../../core/sync/sync_queue.dart';
import '../data/reconciliation_op_submitter.dart';
import 'reconciliation_draft.dart';

class SubmitReconciliationUseCase {
  final SyncQueue queue;
  SubmitReconciliationUseCase(this.queue);

  Future<String> call(ReconciliationDraft draft) => callWithStatus(
        draft,
        OpStatus.pending,
      );

  Future<String> callWithStatus(
    ReconciliationDraft draft,
    OpStatus initialStatus,
  ) {
    return queue.enqueue(
      type: kStockReconciliationOpType,
      payload: draft.toPayload(),
      initialStatus: initialStatus,
    );
  }
}
