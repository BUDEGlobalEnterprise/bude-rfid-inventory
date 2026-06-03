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
  }) async {
    final op = PendingOperation(
      id: _uuid.v4(),
      type: type,
      payload: payload,
      status: OpStatus.pending,
      createdAt: DateTime.now().toUtc(),
    );
    await _box.put(op.id, op.encode());
    _changes.add(null);
    return op.id;
  }

  PendingOperation? getById(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    return PendingOperation.decode(raw);
  }

  List<PendingOperation> all() => _box.values
      .map(PendingOperation.decode)
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  List<PendingOperation> pending() =>
      all().where((o) => o.status == OpStatus.pending).toList();

  List<PendingOperation> failed() =>
      all().where((o) => o.status == OpStatus.failed).toList();

  /// Count of operations not yet successfully sent (pending + inflight + failed).
  int unresolvedCount() =>
      all().where((o) => o.status != OpStatus.succeeded).length;

  /// Stream of `unresolvedCount()` — emits whenever the box mutates.
  Stream<int> unresolvedCountStream() async* {
    yield unresolvedCount();
    await for (final _ in _changes.stream) {
      yield unresolvedCount();
    }
  }

  /// Stream of all operations — emits whenever the box mutates.
  Stream<List<PendingOperation>> watchAll() async* {
    yield all();
    await for (final _ in _changes.stream) {
      yield all();
    }
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
    await update(op.copyWith(
      status: OpStatus.pending,
      attempts: 0,
      clearError: true,
      clearNextRetry: true,
    ));
  }

  Future<void> dispose() async {
    await _changes.close();
  }
}
