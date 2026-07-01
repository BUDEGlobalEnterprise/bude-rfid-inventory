import '../../../core/sync/pending_operation.dart';
import '../../../core/sync/sync_queue.dart';
import '../data/transfer_op_submitter.dart';
import 'transfer_draft.dart';

/// Enqueues a stock transfer onto the sync queue. Returns the op id so the
/// caller can show "Queued — synced as STE-...".
///
/// Does NOT call the API directly — that's the SyncEngine + TransferOpSubmitter's
/// job. This decouples user feedback from network availability and gives us
/// offline-first behavior for free.
class SubmitTransferUseCase {
  final SyncQueue queue;
  SubmitTransferUseCase(this.queue);

  Future<String> call(TransferDraft draft) => callWithStatus(
        draft,
        OpStatus.pending,
      );

  Future<String> callWithStatus(
    TransferDraft draft,
    OpStatus initialStatus, {
    Map<String, dynamic> extraPayload = const {},
  ) {
    return queue.enqueue(
      type: kStockTransferOpType,
      payload: {
        ...draft.toPayload(),
        ...extraPayload,
      },
      initialStatus: initialStatus,
    );
  }
}
