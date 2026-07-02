import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/pending_operation.dart';
import '../../../core/offline/pending_operations_queue.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/presentation/attendance_controller.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/presentation/expenses_screen.dart';

final syncControllerProvider =
    StateNotifierProvider<SyncController, SyncState>((ref) {
  return SyncController(
    ref.watch(pendingOperationsQueueProvider),
    ref.read(attendanceRepositoryProvider),
    ref.read(expenseRepositoryProvider),
  )..bootstrap();
});

/// Orchestrates the single pending-operations queue across features. Each
/// feature repository still owns how its own operation type is replayed; this
/// controller just aggregates the queue and drives retry/discard/manual sync.
class SyncController extends StateNotifier<SyncState> {
  SyncController(this._queue, this._attendance, this._expenses)
      : super(const SyncState());

  final PendingOperationsQueue _queue;
  final AttendanceRepository _attendance;
  final ExpenseRepository _expenses;

  Future<void> load() async {
    state = state.copyWith(operations: await _queue.read());
  }

  /// Called once on app start: load the queue and, if anything is pending,
  /// attempt a silent sync (a no-op offline since failed ops just re-queue).
  Future<void> bootstrap() async {
    await load();
    if (state.operations.isNotEmpty) await syncAll();
  }

  Future<void> syncAll() async {
    state = state.copyWith(isSyncing: true, lastError: null);
    final errors = <String>[];
    final attendanceError = await _attendance.retryPending();
    if (attendanceError != null) errors.add(attendanceError);
    final expenseError = await _expenses.retryDrafts();
    if (expenseError != null) errors.add(expenseError);
    await load();
    state = state.copyWith(
      isSyncing: false,
      lastError: errors.isEmpty ? null : errors.join('\n'),
    );
  }

  Future<void> discard(String id) async {
    await _queue.discard(id);
    await load();
  }

  Future<void> discardAll() async {
    await _queue.clear();
    await load();
  }
}

class SyncState {
  const SyncState({
    this.operations = const [],
    this.isSyncing = false,
    this.lastError,
  });

  final List<PendingHrOperation> operations;
  final bool isSyncing;
  final String? lastError;

  SyncState copyWith({
    List<PendingHrOperation>? operations,
    bool? isSyncing,
    String? lastError,
  }) {
    return SyncState(
      operations: operations ?? this.operations,
      isSyncing: isSyncing ?? this.isSyncing,
      lastError: lastError,
    );
  }
}
