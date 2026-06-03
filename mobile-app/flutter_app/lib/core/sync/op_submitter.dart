import 'package:equatable/equatable.dart';

import 'pending_operation.dart';

/// Result of one submit attempt. Drives [SyncEngine]'s state machine.
sealed class SubmitResult extends Equatable {
  const SubmitResult();

  @override
  List<Object?> get props => [];
}

class SubmitSuccess extends SubmitResult {
  final String serverRef;
  const SubmitSuccess(this.serverRef);

  @override
  List<Object?> get props => [serverRef];
}

/// Transient failure — retry with exponential backoff (5xx, network).
class SubmitRetryable extends SubmitResult {
  final String error;
  const SubmitRetryable(this.error);

  @override
  List<Object?> get props => [error];
}

/// Permanent failure — do not retry (4xx validation, business rule).
/// User must amend or discard via the queue screen.
class SubmitFatal extends SubmitResult {
  final String error;
  const SubmitFatal(this.error);

  @override
  List<Object?> get props => [error];
}

/// Implemented by each operation type (Slice 2 adds StockTransferSubmitter).
abstract class OpSubmitter {
  /// The operation [PendingOperation.type] this submitter handles.
  String get type;

  Future<SubmitResult> submit(PendingOperation op);
}
