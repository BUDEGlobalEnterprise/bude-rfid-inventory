import 'dart:async';

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'pending_operation.dart';

/// Hive-backed persistent queue of pending write operations.
///
/// Stores each op as a JSON-encoded string keyed by id, so no
/// Hive `TypeAdapter` is required.
class SyncQueue {
  static const String boxName = 'bude.sync.pending_ops';

  final Box<String> _box;
  final Uuid _uuid;
  final _changes = StreamController<void>.broadcast();

  SyncQueue({required Box<String> box, Uuid? uuid})
      : _box = box,
        _uuid = uuid ?? const Uuid();

  /// Add a new operation and return its id.
  Future<String> enqueue({
    required String type,
    required Map<String, dynamic> payload,
    OpStatus initialStatus = OpStatus.pending,
  }) async {
    final op = PendingOperation(
      id: _uuid.v4(),
      type: type,
      payload: payload,
      status: initialStatus,
      createdAt: DateTime.now().toUtc(),
    );
    await _box.put(op.id, op.encode());
    _changes.add(null);
    return op.id;
  }

  /// Promote a pendingApproval op to pending so the sync engine picks it up.
  ///
  /// [approvedBy] records the supervisor's username in the payload so it
  /// reaches ERPNext and shows in the audit trail.
  Future<void> approve(String id, {String? approvedBy}) async {
    final op = getById(id);
    if (op == null || op.status != OpStatus.pendingApproval) return;
    final approvedAt = DateTime.now().toUtc().toIso8601String();
    final payload = {
      ...op.payload,
      if (approvedBy != null) 'approved_by': approvedBy,
      'approved_at': approvedAt,
    };
    await update(
      op.copyWith(
        payload: payload,
        status: OpStatus.pending,
        clearError: true,
        clearNextRetry: true,
      ),
    );
  }

  PendingOperation? getById(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    return PendingOperation.decode(raw);
  }

  List<PendingOperation> all() =>
      _box.values.map(PendingOperation.decode).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  List<PendingOperation> pending() =>
      all().where((o) => o.status == OpStatus.pending).toList();

  List<PendingOperation> failed() =>
      all().where((o) => o.status == OpStatus.failed).toList();

  /// Count of operations not yet successfully sent (pendingApproval + pending + inflight + failed).
  int unresolvedCount() =>
      all().where((o) => o.status != OpStatus.succeeded).length;

  /// Stream of `unresolvedCount()` — emits the current value on subscribe,
  /// then again whenever the box mutates.
  Stream<int> unresolvedCountStream() => _withInitial(
        () => unresolvedCount(),
        _changes.stream.map((_) => unresolvedCount()),
      );

  /// Stream of all operations — emits whenever the box mutates.
  Stream<List<PendingOperation>> watchAll() => _withInitial(
        () => all(),
        _changes.stream.map((_) => all()),
      );

  /// Helper: emit an initial value synchronously on subscribe, then
  /// proxy events from [updates]. Avoids `async*` + broadcast-stream races
  /// and gives subscribers a deterministic first event.
  static Stream<T> _withInitial<T>(
    T Function() initial,
    Stream<T> updates,
  ) {
    late StreamController<T> ctrl;
    StreamSubscription<T>? sub;
    ctrl = StreamController<T>(
      onListen: () {
        ctrl.add(initial());
        sub = updates.listen(
          ctrl.add,
          onError: ctrl.addError,
          onDone: ctrl.close,
        );
      },
      onCancel: () => sub?.cancel(),
    );
    return ctrl.stream;
  }

  /// Pick the next pending op whose [PendingOperation.nextRetryAt] (if any)
  /// has elapsed. Returns null if nothing is eligible.
  PendingOperation? nextEligible({DateTime? now}) {
    final clock = now ?? DateTime.now().toUtc();
    for (final op in pending()) {
      final next = op.nextRetryAt;
      if (next == null || !next.isAfter(clock)) return op;
    }
    return null;
  }

  Future<void> update(PendingOperation op) async {
    await _box.put(op.id, op.encode());
    _changes.add(null);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
    _changes.add(null);
  }

  /// Reset a failed op back to pending so the engine retries it.
  Future<void> retry(String id) async {
    final op = getById(id);
    if (op == null) return;
    await update(
      op.copyWith(
        status: OpStatus.pending,
        attempts: 0,
        clearError: true,
        clearNextRetry: true,
      ),
    );
  }

  Future<void> dispose() async {
    await _changes.close();
  }
}
